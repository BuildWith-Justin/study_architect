import 'package:flutter/foundation.dart';

import '../models/study_session.dart';
import '../models/task.dart';
import 'gamification_engine.dart';

/// The only door between the screens and the GamificationEngine.
///
/// Every method is crash-proof: if the engine fails, the problem is
/// printed in the console and the screen carries on as if nothing
/// happened (the save the person just made is never affected). A missed
/// award is repaired by the rebuild that runs at the next app start.
class GamificationHooks {
  GamificationHooks._();

  static GamificationEngine get _engine => GamificationEngine.instance;

  static Future<T?> _guard<T>(String name, Future<T> Function() job) async {
    try {
      final result = await job();
      debugPrint('[Gamification] $name ok');
      return result;
    } catch (e, st) {
      debugPrint('[Gamification] $name failed: $e\n$st');
      return null;
    }
  }

  /// Prints what an award produced, plus the new total, in the console.
  static Future<void> _report(String what, AwardResult? r) async {
    if (r == null) return;
    try {
      final snap = await _engine.getSnapshot();
      final badges = r.newBadges.map((b) => b.id).join(', ');
      debugPrint(
        '[Gamification] $what: +${r.xpAwarded} XP '
        '| total ${snap.totalXp} XP | level ${r.levelBefore} -> ${r.levelAfter} '
        '| streak ${snap.streak.length} | new badges: ${badges.isEmpty ? "none" : badges}'
        '${r.dailyCapReached ? " | daily cap reached" : ""}',
      );
    } catch (_) {
      // Logging only.
    }
  }

  // ------------------------------------------------------------ sessions

  /// After a session was saved as completed (or a completed one edited).
  static Future<AwardResult?> sessionCompleted(StudySession session) async {
    final r = await _guard(
      'sessionCompleted',
      () => _engine.onSessionCompleted(session),
    );
    await _report('session', r);
    return r;
  }

  static Future<void> sessionRemoved(String sessionId) async {
    await _guard('sessionRemoved', () => _engine.onSessionRemoved(sessionId));
  }

  static Future<void> sessionsRemoved(List<String> sessionIds) async {
    await _guard(
      'sessionsRemoved',
      () => _engine.onSessionsRemoved(sessionIds),
    );
  }

  // --------------------------------------------------------------- tasks

  /// After a task was saved as completed.
  static Future<AwardResult?> taskCompleted(Task task) async {
    final r =
        await _guard('taskCompleted', () => _engine.onTaskCompleted(task));
    await _report('task', r);
    return r;
  }

  /// After a task was un-ticked or deleted.
  static Future<void> taskRemoved(String taskId) async {
    await _guard('taskRemoved', () => _engine.onTaskRemoved(taskId));
  }

  // --------------------------------------------------------- exam topics

  static Future<AwardResult?> examTopicPrepared(String examTopicId) async {
    final r = await _guard(
      'examTopicPrepared',
      () => _engine.onExamTopicPrepared(examTopicId),
    );
    await _report('exam topic', r);
    return r;
  }

  static Future<void> examTopicUnprepared(String examTopicId) async {
    await _guard(
      'examTopicUnprepared',
      () => _engine.onExamTopicUnprepared(examTopicId),
    );
  }

  /// Call BEFORE the exam is deleted.
  static Future<void> examRemoved(String examId) async {
    await _guard('examRemoved', () => _engine.onExamRemoved(examId));
  }

  /// After an exam was edited (its topic list may have changed).
  static Future<void> examTopicsEdited() async {
    await _guard('examTopicsEdited', () => _engine.cleanupExamTopicXp());
  }

  // ------------------------------------------------- subjects and topics

  /// Call BEFORE the subject is deleted.
  static Future<void> subjectRemoved(String subjectId) async {
    await _guard('subjectRemoved', () => _engine.onSubjectRemoved(subjectId));
  }

  /// Call BEFORE the topic is deleted.
  static Future<void> topicRemoved(String topicId) async {
    await _guard('topicRemoved', () => _engine.onTopicRemoved(topicId));
  }

  // ------------------------------------------------------------- startup

  /// Runs a couple of seconds after the app starts, in the background:
  /// gives XP to any existing session, task or exam topic that has none
  /// yet (first launch after this update, data pulled from another
  /// device) and unlocks the badges already deserved. It never removes
  /// XP, so it is safe while a sync is still downloading.
  static Future<void> startupRebuild() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final report = await _guard(
      'startupRebuild',
      () => _engine.rebuildFromHistory(),
    );
    if (report == null) return;
    try {
      final snap = await _engine.getSnapshot();
      final badges = report.newBadges.map((b) => b.id).join(', ');
      debugPrint(
        '[Gamification] startup: wrote ${report.written} entries '
        '| total ${snap.totalXp} XP | level ${snap.level.level} '
        '| streak ${snap.streak.length} '
        '| badges ${snap.badgesUnlocked}/${snap.badgesTotal}'
        '${badges.isEmpty ? "" : " | newly unlocked: $badges"}',
      );
    } catch (_) {
      // Logging only.
    }
  }

  /// After a backup was restored (an older backup has no XP in it).
  static Future<void> afterRestore() async {
    await _guard('afterRestore', () => _engine.rebuildFromHistory());
  }
}
