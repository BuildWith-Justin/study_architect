import 'dart:async';

import '../core/data_refresh_bus.dart';
import '../models/study_session.dart';
import '../models/task.dart';
import '../models/xp_entry.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/exam_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/xp_repository.dart';
import '../utils/date_utils.dart';
import 'badge_defs.dart';
import 'streak_calculator.dart';
import 'xp_rules.dart';

/// What one event (a finished session, a ticked task...) produced. The UI
/// uses it for the celebration on Session Complete.
class AwardResult {
  final int xpAwarded;
  final bool streakBonus;
  final bool dailyCapReached;
  final int levelBefore;
  final int levelAfter;
  final List<BadgeDef> newBadges;

  const AwardResult({
    this.xpAwarded = 0,
    this.streakBonus = false,
    this.dailyCapReached = false,
    required this.levelBefore,
    required this.levelAfter,
    this.newBadges = const <BadgeDef>[],
  });

  factory AwardResult.none(int level) =>
      AwardResult(levelBefore: level, levelAfter: level);

  bool get leveledUp => levelAfter > levelBefore;
  bool get hasNews =>
      xpAwarded > 0 || leveledUp || newBadges.isNotEmpty || dailyCapReached;
}

/// Everything the Home header and the Achievements screen need.
class GamificationSnapshot {
  final int totalXp;
  final LevelInfo level;
  final int xpToday;
  final StreakResult streak;

  /// Days (yyyy-MM-dd) that count for the streak (10+ minutes studied).
  final Set<String> studyDays;
  final int badgesUnlocked;
  final int badgesTotal;

  const GamificationSnapshot({
    required this.totalXp,
    required this.level,
    required this.xpToday,
    required this.streak,
    required this.studyDays,
    required this.badgesUnlocked,
    required this.badgesTotal,
  });
}

/// The streak numbers shown on Home, Progress and the weekly report, all
/// computed with the same rule so the screens can never disagree.
class StreakInfo {
  final StreakResult current;
  final int best;

  /// Days (yyyy-MM-dd) that count for the streak (10+ minutes studied).
  final Set<String> studyDays;

  const StreakInfo({
    required this.current,
    required this.best,
    required this.studyDays,
  });
}

class RebuildReport {
  final int written;
  final int removed;
  final List<BadgeDef> newBadges;

  const RebuildReport({
    required this.written,
    required this.removed,
    required this.newBadges,
  });
}

/// The brain of Step 13. Screens call the on... methods after they save
/// something; the engine decides the XP, writes the ledger, unlocks
/// badges and tells Home to refresh.
///
/// Jobs run one after the other (see _run), so two quick events can never
/// read the ledger at the same time and double count.
class GamificationEngine {
  GamificationEngine._();
  static final GamificationEngine instance = GamificationEngine._();

  final _xp = XpRepository();
  final _badges = AchievementRepository();
  final _sessions = SessionRepository();
  final _tasks = TaskRepository();
  final _exams = ExamRepository();

  /// Result of the latest award per session, kept until the celebration
  /// screen reads it (see takeRecentAward).
  final Map<String, AwardResult> _recentAwards = <String, AwardResult>{};

  Future<void> _tail = Future<void>.value();

  Future<T> _run<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await job());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _notify() => DataRefreshBus.instance.notify(RefreshScope.achievements);

  Future<int> _currentLevel() async => levelForXp(await _xp.getTotalXp()).level;

  // ------------------------------------------------------------ sessions

  /// Call after a session was saved as completed (and again if it is
  /// edited). Safe to call twice: the second call changes nothing.
  Future<AwardResult> onSessionCompleted(StudySession session) async {
    final result = await _awardSession(session);
    if (result.hasNews) _recentAwards[session.id] = result;
    return result;
  }

  /// The celebration screen reads the result of the award that just
  /// happened for a session (and removes it, so it is shown only once).
  AwardResult? takeRecentAward(String sessionId) =>
      _recentAwards.remove(sessionId);

  Future<AwardResult> _awardSession(StudySession session) {
    return _run(() async {
      final levelBefore = await _currentLevel();
      final base = sessionBaseXp(session.actualDuration);

      // Not completed, or too short: it must not hold any XP.
      if (!session.complete || base == 0) {
        final removed = await _xp.removeBySource(XpSource.session, session.id);
        if (removed > 0) _notify();
        return AwardResult.none(levelBefore);
      }

      final all = await _sessions.getAll();
      final merged = <StudySession>[
        for (final s in all)
          if (s.id != session.id) s,
        session,
      ];
      final days = qualifyingDays(merged);
      final streak = streakAsOf(days, session.scheduledDate).length;
      final withBonus = applyStreakBonus(base, streak);

      final earnedElsewhere = await _xp.getXpForDayBySource(
        session.scheduledDate,
        XpSource.session,
        excludeSourceId: session.id,
      );
      final remaining = XpRules.dailySessionXpCap - earnedElsewhere;
      if (remaining <= 0) {
        final removed = await _xp.removeBySource(XpSource.session, session.id);
        if (removed > 0) _notify();
        return AwardResult(
          dailyCapReached: true,
          levelBefore: levelBefore,
          levelAfter: levelBefore,
        );
      }

      final amount = withBonus < remaining ? withBonus : remaining;
      final bonus = amount > base;
      final changed = await _xp.upsert(
        XpEntry.forSource(
          type: XpSource.session,
          sourceId: session.id,
          amount: amount,
          reason: _sessionReason(base, bonus),
          earnedAt: _sessionEarnedAt(session),
        ),
      );
      return _finish(
        levelBefore,
        changed: changed,
        amount: amount,
        bonus: bonus,
        capped: amount < withBonus,
      );
    });
  }

  /// Call after one session is deleted.
  Future<void> onSessionRemoved(String sessionId) =>
      onSessionsRemoved([sessionId]);

  /// Call after several sessions are deleted (a whole series).
  Future<void> onSessionsRemoved(List<String> sessionIds) {
    return _run(() async {
      var removed = 0;
      for (final id in sessionIds) {
        removed += await _xp.removeBySource(XpSource.session, id);
      }
      if (removed > 0) _notify();
    });
  }

  // --------------------------------------------------------------- tasks

  /// Call when a task is ticked as completed.
  Future<AwardResult> onTaskCompleted(Task task) {
    return _run(() async {
      final levelBefore = await _currentLevel();
      if (!task.completed) {
        final removed = await _xp.removeBySource(XpSource.task, task.id);
        if (removed > 0) _notify();
        return AwardResult.none(levelBefore);
      }

      final now = DateTime.now();
      final days = qualifyingDays(await _sessions.getAll());
      final amount = applyStreakBonus(
        XpRules.taskXp,
        streakAsOf(days, now).length,
      );
      final changed = await _xp.award(
        XpEntry.forSource(
          type: XpSource.task,
          sourceId: task.id,
          amount: amount,
          reason: 'Task completed',
          earnedAt: now,
        ),
      );
      return _finish(
        levelBefore,
        changed: changed,
        amount: amount,
        bonus: amount > XpRules.taskXp,
      );
    });
  }

  /// Call when a task is un-ticked or deleted: its XP goes away.
  Future<void> onTaskRemoved(String taskId) {
    return _run(() async {
      final removed = await _xp.removeBySource(XpSource.task, taskId);
      if (removed > 0) _notify();
    });
  }

  // --------------------------------------------------------- exam topics

  /// Call when a topic of an exam checklist is ticked as prepared.
  Future<AwardResult> onExamTopicPrepared(String examTopicId) {
    return _run(() async {
      final levelBefore = await _currentLevel();
      final changed = await _xp.award(
        XpEntry.forSource(
          type: XpSource.examTopic,
          sourceId: examTopicId,
          amount: XpRules.examTopicXp,
          reason: 'Exam topic prepared',
          earnedAt: DateTime.now(),
        ),
      );
      return _finish(
        levelBefore,
        changed: changed,
        amount: XpRules.examTopicXp,
      );
    });
  }

  /// Call when an exam topic is un-ticked.
  Future<void> onExamTopicUnprepared(String examTopicId) {
    return _run(() async {
      final removed = await _xp.removeBySource(XpSource.examTopic, examTopicId);
      if (removed > 0) _notify();
    });
  }

  /// Call BEFORE deleting an exam (deleting it also deletes its topic
  /// links, and the engine needs their ids to remove the XP).
  Future<void> onExamRemoved(String examId) {
    return _run(() async {
      final links = await _exams.getTopicLinks(examId);
      var removed = 0;
      for (final link in links) {
        removed += await _xp.removeBySource(XpSource.examTopic, link.id);
      }
      if (removed > 0) _notify();
    });
  }

  /// Removes exam-topic XP whose checklist line no longer exists or is no
  /// longer ticked (for example after an exam's topic list was edited).
  Future<void> cleanupExamTopicXp() {
    return _run(() async {
      final links = await _exams.getAllTopicLinks();
      final keep = <String>{
        for (final l in links)
          if (l.prepared) l.id,
      };
      final removed = await _removeMissing(XpSource.examTopic, keep);
      if (removed > 0) _notify();
    });
  }

  /// Call BEFORE deleting a subject (deleting it also deletes its
  /// sessions, tasks and exams, and the engine needs their ids).
  Future<void> onSubjectRemoved(String subjectId) {
    return _run(() async {
      var removed = 0;
      for (final s in await _sessions.getForSubject(subjectId)) {
        removed += await _xp.removeBySource(XpSource.session, s.id);
      }
      for (final t in await _tasks.getForSubject(subjectId)) {
        removed += await _xp.removeBySource(XpSource.task, t.id);
      }
      for (final e in await _exams.getForSubject(subjectId)) {
        for (final l in await _exams.getTopicLinks(e.id)) {
          removed += await _xp.removeBySource(XpSource.examTopic, l.id);
        }
      }
      if (removed > 0) _notify();
    });
  }

  /// Call BEFORE deleting a topic (deleting it also removes it from the
  /// checklists of every exam).
  Future<void> onTopicRemoved(String topicId) {
    return _run(() async {
      var removed = 0;
      for (final l in await _exams.getAllTopicLinks()) {
        if (l.topicId == topicId) {
          removed += await _xp.removeBySource(XpSource.examTopic, l.id);
        }
      }
      if (removed > 0) _notify();
    });
  }

  // ------------------------------------------------------------ snapshot

  /// Everything the badges look at (used for the progress bars of locked
  /// badges on the Achievements screen).
  Future<GamificationStats> getStats() => _collectStats();

  /// Current streak, best streak and the study days, for any screen that
  /// shows a streak.
  Future<StreakInfo> getStreakInfo({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final days = qualifyingDays(await _sessions.getAll());
    return StreakInfo(
      current: streakAsOf(days, n),
      best: bestStreak(days),
      studyDays: days,
    );
  }

  Future<GamificationSnapshot> getSnapshot({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final total = await _xp.getTotalXp();
    final xpToday = await _xp.getXpForDay(n);
    final days = qualifyingDays(await _sessions.getAll());
    final unlocked = await _badges.getUnlockedIds();
    return GamificationSnapshot(
      totalXp: total,
      level: levelForXp(total),
      xpToday: xpToday,
      streak: streakAsOf(days, n),
      studyDays: days,
      badgesUnlocked: unlocked.length,
      badgesTotal: kBadges.length,
    );
  }

  // ------------------------------------------------------------- rebuild

  /// Recomputes the ledger from the sessions, tasks and exam checklists
  /// that exist right now: gives XP to everything that does not have it
  /// yet (first launch after this update, restored backups, data pulled
  /// from another device) and unlocks the badges you already deserve.
  ///
  /// With [removeOrphans] it also removes XP whose source no longer
  /// exists. Only use that from an explicit user action, never while a
  /// sync may still be downloading.
  Future<RebuildReport> rebuildFromHistory({bool removeOrphans = false}) {
    return _run(() async {
      final now = DateTime.now();
      final sessions = await _sessions.getAll();
      final tasks = await _tasks.getAll();
      final links = await _exams.getAllTopicLinks();
      final days = qualifyingDays(sessions);

      var written = 0;
      var removed = 0;

      // Sessions, oldest first, so the daily cap fills in the order the
      // sessions really happened.
      final done = sessions.where((s) => s.complete).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final earnedByDay = <String, int>{};
      final keepSessions = <String>{};
      for (final s in done) {
        final base = sessionBaseXp(s.actualDuration);
        if (base == 0) continue;
        final key = dayKey(s.scheduledDate);
        final used = earnedByDay[key] ?? 0;
        final remaining = XpRules.dailySessionXpCap - used;
        if (remaining <= 0) continue;
        final withBonus = applyStreakBonus(
          base,
          streakAsOf(days, s.scheduledDate).length,
        );
        final amount = withBonus < remaining ? withBonus : remaining;
        earnedByDay[key] = used + amount;
        keepSessions.add(s.id);
        final changed = await _xp.upsert(
          XpEntry.forSource(
            type: XpSource.session,
            sourceId: s.id,
            amount: amount,
            reason: _sessionReason(base, amount > base),
            earnedAt: _sessionEarnedAt(s),
          ),
        );
        if (changed) written++;
      }

      // Tasks have no completion date, so old ones are dated at their
      // due date (or today if it is still in the future).
      final keepTasks = <String>{};
      for (final t in tasks.where((t) => t.completed)) {
        keepTasks.add(t.id);
        final when = t.dueDate.isAfter(now) ? now : t.dueDate;
        final amount = applyStreakBonus(
          XpRules.taskXp,
          streakAsOf(days, when).length,
        );
        final added = await _xp.award(
          XpEntry.forSource(
            type: XpSource.task,
            sourceId: t.id,
            amount: amount,
            reason: 'Task completed',
            earnedAt: when,
          ),
        );
        if (added) written++;
      }

      final keepTopics = <String>{};
      for (final l in links.where((l) => l.prepared)) {
        keepTopics.add(l.id);
        final added = await _xp.award(
          XpEntry.forSource(
            type: XpSource.examTopic,
            sourceId: l.id,
            amount: XpRules.examTopicXp,
            reason: 'Exam topic prepared',
            earnedAt: now,
          ),
        );
        if (added) written++;
      }

      if (removeOrphans) {
        removed += await _removeMissing(XpSource.session, keepSessions);
        removed += await _removeMissing(XpSource.task, keepTasks);
        removed += await _removeMissing(XpSource.examTopic, keepTopics);
      }

      final newBadges = await _evaluateBadges();
      if (written > 0 || removed > 0 || newBadges.isNotEmpty) _notify();

      return RebuildReport(
        written: written,
        removed: removed,
        newBadges: newBadges,
      );
    });
  }

  Future<int> _removeMissing(XpSource type, Set<String> keep) async {
    final existing = await _xp.getSourceIds(type);
    var count = 0;
    for (final id in existing.difference(keep)) {
      count += await _xp.removeBySource(type, id);
    }
    return count;
  }

  // -------------------------------------------------------------- badges

  Future<GamificationStats> _collectStats() async {
    final sessions = await _sessions.getAll();
    final done = sessions.where((s) => s.complete).toList();

    var totalMinutes = 0;
    var longest = 0;
    var countedSessions = 0;
    for (final s in done) {
      final m = s.actualDuration ?? 0;
      totalMinutes += m;
      if (m > longest) longest = m;
      if (m >= XpRules.minSessionMinutes) countedSessions++;
    }

    final tasks = await _tasks.getAll();
    final links = await _exams.getAllTopicLinks();
    final byExam = <String, List<bool>>{};
    for (final l in links) {
      byExam.putIfAbsent(l.examId, () => <bool>[]).add(l.prepared);
    }
    final fullyPrepared =
        byExam.values.where((v) => v.isNotEmpty && v.every((p) => p)).length;

    final days = qualifyingDays(sessions);
    final totalXp = await _xp.getTotalXp();

    return GamificationStats(
      totalFocusMinutes: totalMinutes,
      completedSessions: countedSessions,
      longestSessionMinutes: longest,
      completedTasks: tasks.where((t) => t.completed).length,
      preparedExamTopics: links.where((l) => l.prepared).length,
      examsFullyPrepared: fullyPrepared,
      currentStreak: streakAsOf(days, DateTime.now()).length,
      bestStreak: bestStreak(days),
      level: levelForXp(totalXp).level,
      totalXp: totalXp,
    );
  }

  /// Unlocks every badge whose condition is now met and returns the ones
  /// that were unlocked just now (never an already unlocked badge).
  Future<List<BadgeDef>> _evaluateBadges() async {
    final stats = await _collectStats();
    final unlocked = await _badges.getUnlockedIds();
    final fresh = <BadgeDef>[];
    for (final b in kBadges) {
      if (unlocked.contains(b.id)) continue;
      if (b.isEarned(stats) && await _badges.unlock(b.id)) {
        fresh.add(b);
      }
    }
    return fresh;
  }

  // ------------------------------------------------------------- helpers

  Future<AwardResult> _finish(
    int levelBefore, {
    required bool changed,
    required int amount,
    bool bonus = false,
    bool capped = false,
  }) async {
    final newBadges = await _evaluateBadges();
    final levelAfter = await _currentLevel();
    if (changed || newBadges.isNotEmpty) _notify();
    return AwardResult(
      xpAwarded: changed ? amount : 0,
      streakBonus: changed && bonus,
      dailyCapReached: changed && capped,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newBadges: newBadges,
    );
  }

  String _sessionReason(int minutes, bool bonus) {
    final extra = bonus ? ' +${XpRules.streakBonusPercent}% streak' : '';
    return '$minutes min focus$extra';
  }

  /// Session XP belongs to the day the session was scheduled on, the same
  /// day Home uses for "today's minutes".
  DateTime _sessionEarnedAt(StudySession s) {
    final now = DateTime.now();
    final d = s.scheduledDate;
    if (isSameDay(d, now)) return now;
    return DateTime(d.year, d.month, d.day, 12);
  }
}
