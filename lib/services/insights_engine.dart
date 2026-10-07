import 'package:flutter/material.dart';

import '../models/exam.dart';
import '../models/insight.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';

/// V2 Step 14: pattern-based study insights.
///
/// Pure Dart: give it the data, get back a ranked list. It never reads
/// the database or the network itself, so it is cheap and easy to test.
/// Every rule only fires when its condition is clearly true, so the list
/// can safely be empty on a quiet day.
class InsightsEngine {
  InsightsEngine._();

  /// A day counts for the streak from this many minutes (same as the
  /// gamification rule).
  static const int streakMinMinutes = 10;

  /// Pattern insights need at least this many recent completed sessions.
  static const int minSessionsForPatterns = 8;

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Returns every applicable insight, most important first.
  static List<Insight> generate({
    required List<StudySession> sessions,
    required List<Subject> subjects,
    required List<Task> tasks,
    required List<Exam> exams,
    required Map<String, ExamProgress> examProgress,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayStart = startOfDay(today);

    final done = sessions
        .where((s) => s.complete && (s.actualDuration ?? 0) > 0)
        .toList();
    final subjectsById = {for (final s in subjects) s.id: s};

    final minutesByDay = <DateTime, int>{};
    final lastStudyBySubject = <String, DateTime>{};
    final sessionCountBySubject = <String, int>{};
    for (final s in done) {
      final day = startOfDay(s.scheduledDate);
      minutesByDay[day] = (minutesByDay[day] ?? 0) + (s.actualDuration ?? 0);
      final prev = lastStudyBySubject[s.subjectId];
      if (prev == null || day.isAfter(prev)) {
        lastStudyBySubject[s.subjectId] = day;
      }
      sessionCountBySubject[s.subjectId] =
          (sessionCountBySubject[s.subjectId] ?? 0) + 1;
    }

    final out = <Insight>[];

    out.addAll(_examInsights(
      exams: exams,
      examProgress: examProgress,
      subjectsById: subjectsById,
      lastStudyBySubject: lastStudyBySubject,
      today: today,
    ));
    out.addAll(_taskInsights(tasks: tasks, today: today));
    out.addAll(_streakInsights(minutesByDay: minutesByDay, today: today));
    out.addAll(_neglectedSubject(
      subjects: subjects,
      exams: exams,
      lastStudyBySubject: lastStudyBySubject,
      sessionCountBySubject: sessionCountBySubject,
      today: today,
    ));
    out.addAll(_weeklyPace(
      subjects: subjects,
      minutesByDay: minutesByDay,
      today: today,
    ));
    out.addAll(_weekOverWeek(minutesByDay: minutesByDay, today: today));
    out.addAll(_patternInsights(
      done: done,
      minutesByDay: minutesByDay,
      today: today,
    ));

    if (done.isEmpty) {
      out.add(const Insight(
        id: 'first-session',
        kind: InsightKind.firstSession,
        icon: Icons.rocket_launch_rounded,
        title: 'Start your first session',
        message:
            'Log a study session and your suggestions will get smarter after a few of them.',
        priority: 20,
        snooze: Duration(days: 3),
      ));
    }

    out.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
    });
    return out;
  }

  // ---------------------------------------------------------------- exams

  static List<Insight> _examInsights({
    required List<Exam> exams,
    required Map<String, ExamProgress> examProgress,
    required Map<String, Subject> subjectsById,
    required Map<String, DateTime> lastStudyBySubject,
    required DateTime today,
  }) {
    final out = <Insight>[];
    final todayStart = startOfDay(today);

    for (final e in exams) {
      final left = e.daysLeft(today);
      if (left < 0 || left > 14) continue;

      final name = subjectsById[e.subjectId]?.name ?? e.title;
      final p = examProgress[e.id] ?? const ExamProgress.empty();
      final when = left == 0
          ? 'is today'
          : left == 1
              ? 'is tomorrow'
              : 'is in $left days';

      final last = lastStudyBySubject[e.subjectId];
      final daysSinceStudy =
          last == null ? 999 : todayStart.difference(last).inDays;

      if (p.total > 0 && p.prepared < p.total && left <= 7) {
        out.add(Insight(
          id: 'exam:${e.id}',
          kind: InsightKind.examPrep,
          icon: Icons.event_note_rounded,
          title: '$name exam $when',
          message:
              '${p.prepared} of ${p.total} topics prepared. ${p.total - p.prepared} still to review.',
          priority: 95 - left * 3,
          action: InsightAction.progress,
          actionLabel: 'See progress',
        ));
      } else if (daysSinceStudy >= 7) {
        out.add(Insight(
          id: 'exam-gap:${e.id}',
          kind: InsightKind.examPrep,
          icon: Icons.event_note_rounded,
          title: '$name exam $when',
          message: last == null
              ? "You haven't logged any study time for $name yet."
              : "You haven't studied $name in $daysSinceStudy days.",
          priority: 82 - left,
          action: InsightAction.progress,
          actionLabel: 'See progress',
        ));
      } else if (p.total == 0 && left <= 10) {
        out.add(Insight(
          id: 'exam-topics:${e.id}',
          kind: InsightKind.examPrep,
          icon: Icons.checklist_rounded,
          title: '$name exam $when',
          message:
              'Add topics to its checklist so you can track your preparation.',
          priority: 45,
          snooze: const Duration(days: 2),
        ));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- tasks

  static List<Insight> _taskInsights({
    required List<Task> tasks,
    required DateTime today,
  }) {
    final out = <Insight>[];
    final todayStart = startOfDay(today);
    final open = tasks.where((t) => !t.completed).toList();

    final overdue =
        open.where((t) => startOfDay(t.dueDate).isBefore(todayStart)).length;
    if (overdue > 0) {
      out.add(Insight(
        id: 'overdue',
        kind: InsightKind.overdueTasks,
        icon: Icons.assignment_late_rounded,
        title: overdue == 1 ? '1 overdue task' : '$overdue overdue tasks',
        message:
            'Clearing the oldest one first stops them piling up.',
        priority: 72,
        action: InsightAction.tasks,
        actionLabel: 'Open tasks',
      ));
    }

    final dueToday =
        open.where((t) => isSameDay(t.dueDate, today)).length;
    if (dueToday > 0 && today.hour >= 16) {
      out.add(Insight(
        id: 'due-today:${_dateKey(todayStart)}',
        kind: InsightKind.tasksDueToday,
        icon: Icons.today_rounded,
        title: dueToday == 1
            ? '1 task due today'
            : '$dueToday tasks due today',
        message: 'The day is nearly over, so now is a good time to finish it.',
        priority: 58,
        action: InsightAction.tasks,
        actionLabel: 'Open tasks',
      ));
    }
    return out;
  }

  // --------------------------------------------------------------- streak

  static List<Insight> _streakInsights({
    required Map<DateTime, int> minutesByDay,
    required DateTime today,
  }) {
    final todayStart = startOfDay(today);
    final todayMinutes = minutesByDay[todayStart] ?? 0;

    // Count back from yesterday.
    var cursor = _prevDay(todayStart);
    var streak = 0;
    while ((minutesByDay[cursor] ?? 0) >= streakMinMinutes) {
      streak++;
      cursor = _prevDay(cursor);
    }

    if (streak >= 3 && todayMinutes < streakMinMinutes && today.hour >= 17) {
      final remaining = streakMinMinutes - todayMinutes;
      return [
        Insight(
          id: 'streak:${_dateKey(todayStart)}',
          kind: InsightKind.streakRisk,
          icon: Icons.local_fire_department_rounded,
          title: 'Keep your $streak-day streak alive',
          message:
              'Study for $remaining more minute${remaining == 1 ? '' : 's'} today to extend it.',
          priority: 88,
        ),
      ];
    }
    return const [];
  }

  // ------------------------------------------------------ neglected subject

  static List<Insight> _neglectedSubject({
    required List<Subject> subjects,
    required List<Exam> exams,
    required Map<String, DateTime> lastStudyBySubject,
    required Map<String, int> sessionCountBySubject,
    required DateTime today,
  }) {
    final todayStart = startOfDay(today);

    // Subjects with an exam in the next 14 days are already handled by
    // the exam rules.
    final examSubjects = {
      for (final e in exams)
        if (e.daysLeft(today) >= 0 && e.daysLeft(today) <= 14) e.subjectId,
    };

    Subject? worst;
    var worstDays = 0;
    for (final s in subjects) {
      if (examSubjects.contains(s.id)) continue;
      if ((sessionCountBySubject[s.id] ?? 0) < 2) continue; // not a routine yet
      final last = lastStudyBySubject[s.id];
      if (last == null) continue;
      final days = todayStart.difference(last).inDays;
      if (days >= 5 && days > worstDays) {
        worst = s;
        worstDays = days;
      }
    }

    if (worst == null) return const [];
    final capped = worstDays > 14 ? 14 : worstDays;
    return [
      Insight(
        id: 'neglected:${worst.id}',
        kind: InsightKind.neglectedSubject,
        icon: Icons.hourglass_bottom_rounded,
        title: '${worst.name} needs attention',
        message:
            "You haven't studied it for $worstDays days. A short session keeps it fresh.",
        priority: 50 + capped,
        snooze: const Duration(days: 3),
      ),
    ];
  }

  // ---------------------------------------------------------- weekly pace

  static List<Insight> _weeklyPace({
    required List<Subject> subjects,
    required Map<DateTime, int> minutesByDay,
    required DateTime today,
  }) {
    final goal =
        subjects.fold<int>(0, (sum, s) => sum + s.weeklyTargetMinutes);
    if (goal <= 0) return const [];

    final weekStart = startOfWeek(today);
    final weekMinutes = _sumDays(minutesByDay, weekStart, today.weekday);
    final progress = weekMinutes / goal;
    final weekKey = _dateKey(weekStart);

    if (today.weekday >= DateTime.thursday && progress < 0.5) {
      return [
        Insight(
          id: 'pace:$weekKey',
          kind: InsightKind.weeklyPace,
          icon: Icons.trending_down_rounded,
          title: "You're behind on this week's target",
          message:
              '${formatDuration(weekMinutes)} of ${formatDuration(goal)} (${(progress * 100).round()}%) with the week more than half over.',
          priority: 66,
          action: InsightAction.progress,
          actionLabel: 'See progress',
        ),
      ];
    }

    if (progress >= 0.85 && progress < 1) {
      final left = goal - weekMinutes;
      return [
        Insight(
          id: 'pace-close:$weekKey',
          kind: InsightKind.weeklyPace,
          icon: Icons.flag_rounded,
          title: 'Almost at your weekly target',
          message: 'Only ${formatDuration(left)} to go.',
          priority: 42,
        ),
      ];
    }
    return const [];
  }

  // ------------------------------------------------------- week over week

  static List<Insight> _weekOverWeek({
    required Map<DateTime, int> minutesByDay,
    required DateTime today,
  }) {
    final t = startOfDay(today);
    final last7 =
        _sumDays(minutesByDay, DateTime(t.year, t.month, t.day - 6), 7);
    final prev7 =
        _sumDays(minutesByDay, DateTime(t.year, t.month, t.day - 13), 7);
    final weekKey = _dateKey(startOfWeek(today));

    if (prev7 >= 120 && last7 < prev7 * 0.6) {
      final drop = (((prev7 - last7) / prev7) * 100).round();
      return [
        Insight(
          id: 'drop:$weekKey',
          kind: InsightKind.weeklyDrop,
          icon: Icons.south_east_rounded,
          title: 'Your study time dropped',
          message:
              '$drop% less than the 7 days before (${formatDuration(last7)} vs ${formatDuration(prev7)}).',
          priority: 54,
          action: InsightAction.progress,
          actionLabel: 'See progress',
          snooze: const Duration(days: 3),
        ),
      ];
    }

    if (prev7 >= 60 && last7 >= prev7 * 1.25) {
      final rise = (((last7 - prev7) / prev7) * 100).round();
      return [
        Insight(
          id: 'rise:$weekKey',
          kind: InsightKind.weeklyRise,
          icon: Icons.north_east_rounded,
          title: 'Great momentum',
          message:
              'You studied $rise% more in the last 7 days (${formatDuration(last7)} vs ${formatDuration(prev7)}).',
          priority: 30,
          snooze: const Duration(days: 7),
        ),
      ];
    }
    return const [];
  }

  // ------------------------------------------------------------- patterns

  static List<Insight> _patternInsights({
    required List<StudySession> done,
    required Map<DateTime, int> minutesByDay,
    required DateTime today,
  }) {
    final out = <Insight>[];
    final t = startOfDay(today);
    final since60 = DateTime(t.year, t.month, t.day - 60);

    final recent = done
        .where((s) => !startOfDay(s.scheduledDate).isBefore(since60))
        .toList();
    if (recent.length < minSessionsForPatterns) return out;

    // --- time of day -------------------------------------------------
    String bucketOf(int hour) {
      if (hour >= 5 && hour < 12) return 'morning';
      if (hour >= 12 && hour < 17) return 'afternoon';
      if (hour >= 17 && hour < 22) return 'evening';
      return 'night';
    }

    final minutesByBucket = <String, int>{};
    final ratingSum = <String, int>{};
    final ratingCount = <String, int>{};
    var totalMinutes = 0;
    for (final s in recent) {
      final b = bucketOf(s.startTime.hour);
      final m = s.actualDuration ?? 0;
      minutesByBucket[b] = (minutesByBucket[b] ?? 0) + m;
      totalMinutes += m;
      if (s.rating != null) {
        ratingSum[b] = (ratingSum[b] ?? 0) + s.rating!;
        ratingCount[b] = (ratingCount[b] ?? 0) + 1;
      }
    }

    if (totalMinutes > 0) {
      final top = minutesByBucket.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      final share = ((top.value / totalMinutes) * 100).round();
      if (share >= 45) {
        out.add(Insight(
          id: 'pattern-time',
          kind: InsightKind.bestTimeOfDay,
          icon: Icons.wb_twilight_rounded,
          title: 'You study best in the ${top.key}',
          message:
              '$share% of your recent study time happens then. Protect that window for your hardest subject.',
          priority: 38,
          snooze: const Duration(days: 7),
        ));
      }
    }

    // Average rating per bucket, only buckets with 3+ rated sessions.
    final avgByBucket = <String, double>{
      for (final b in ratingCount.keys)
        if ((ratingCount[b] ?? 0) >= 3) b: ratingSum[b]! / ratingCount[b]!,
    };
    if (avgByBucket.length >= 2) {
      final entries = avgByBucket.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = entries.first;
      final worst = entries.last;
      if (best.value - worst.value >= 0.5) {
        out.add(Insight(
          id: 'pattern-rating',
          kind: InsightKind.bestTimeOfDay,
          icon: Icons.sentiment_satisfied_alt_rounded,
          title: 'You rate ${best.key} sessions highest',
          message:
              'Average ${best.value.toStringAsFixed(1)}/5 in the ${best.key} vs ${worst.value.toStringAsFixed(1)}/5 in the ${worst.key}.',
          priority: 44,
          snooze: const Duration(days: 7),
        ));
      }
    }

    // --- weakest weekday (needs 4 weeks of history) ------------------
    final firstDay = done
        .map((s) => startOfDay(s.scheduledDate))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    if (t.difference(firstDay).inDays >= 28) {
      final byWeekday = List<int>.filled(8, 0); // index 1..7
      var total28 = 0;
      for (var i = 0; i < 28; i++) {
        final d = DateTime(t.year, t.month, t.day - i);
        final m = minutesByDay[d] ?? 0;
        byWeekday[d.weekday] += m;
        total28 += m;
      }
      if (total28 >= 180) {
        var weakest = 1;
        for (var wd = 2; wd <= 7; wd++) {
          if (byWeekday[wd] < byWeekday[weakest]) weakest = wd;
        }
        if (byWeekday[weakest] == 0) {
          final name = _weekdayNames[weakest - 1];
          out.add(Insight(
            id: 'pattern-day:$weakest',
            kind: InsightKind.weakDay,
            icon: Icons.calendar_today_rounded,
            title: 'You never study on ${name}s',
            message:
                'Nothing logged on a $name in the last 4 weeks. Even 20 minutes would balance your week.',
            priority: 36,
            snooze: const Duration(days: 7),
          ));
        }
      }
    }

    return out;
  }

  // -------------------------------------------------------------- helpers

  static DateTime _prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  /// Sum of minutes over [days] consecutive days starting at [start].
  static int _sumDays(Map<DateTime, int> byDay, DateTime start, int days) {
    var total = 0;
    for (var i = 0; i < days; i++) {
      total += byDay[DateTime(start.year, start.month, start.day + i)] ?? 0;
    }
    return total;
  }

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
