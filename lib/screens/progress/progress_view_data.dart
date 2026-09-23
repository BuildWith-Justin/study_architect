import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/study_stats.dart';
import '../../utils/study_stats.dart' as study_stats;
import '../../utils/study_insights.dart';
import '../../widgets/simple_bar_chart.dart';

enum ProgressPeriod { week, month, allTime }

class ProgressViewData {
  final ProgressPeriod period;
  final int totalMinutes;
  final int targetMinutes;
  final List<BarChartPoint> chartPoints;
  final Map<Subject, int> subjectPerformancePercent;
  final int streak;
  final int longestStreak;
  final List<StudyInsight> insights;

  const ProgressViewData({
    required this.period,
    required this.totalMinutes,
    required this.targetMinutes,
    required this.chartPoints,
    required this.subjectPerformancePercent,
    required this.streak,
    required this.longestStreak,
    required this.insights,
  });

  static Future<ProgressViewData> load(ProgressPeriod period) async {
    final studentRepo = StudentRepository();
    final subjectRepo = SubjectRepository();
    final sessionRepo = SessionRepository();

    final student = await studentRepo.getCurrent();
    final subjects = await subjectRepo.getAll();
    final completedDates = await sessionRepo.getCompletedDates();
    final now = DateTime.now();

    List<StudySession> periodSessions;
    List<BarChartPoint> chartPoints;
    int targetMinutes;
    double periodWeeks;

    switch (period) {
      case ProgressPeriod.week:
        final weekStart = startOfWeek(now);
        final weekEnd = endOfWeek(now);
        periodSessions = await sessionRepo.getForRange(weekStart, weekEnd);
        const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        chartPoints = List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final minutes = completedMinutesForDate(periodSessions, day);
          return BarChartPoint(label: labels[i], value: minutes);
        });
        targetMinutes = student?.weeklyGoalMinutes ?? 0;
        periodWeeks = 1;
        break;

      case ProgressPeriod.month:
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        periodSessions = await sessionRepo.getForRange(monthStart, monthEnd);
        // Bucket into calendar weeks within the month.
        final weekBuckets = <int, int>{};
        for (final session in periodSessions.where((s) => s.complete)) {
          final weekIndex = ((session.scheduledDate.day - 1) / 7).floor();
          weekBuckets[weekIndex] = (weekBuckets[weekIndex] ?? 0) + (session.actualDuration ?? 0);
        }
        final weekCount = (monthEnd.difference(monthStart).inDays / 7).ceil();
        chartPoints = List.generate(weekCount, (i) {
          return BarChartPoint(label: 'W${i + 1}', value: weekBuckets[i] ?? 0);
        });
        final daysInMonth = monthEnd.difference(monthStart).inDays;
        targetMinutes = (student?.dailyGoalMinutes ?? 0) * daysInMonth;
        periodWeeks = daysInMonth / 7;
        break;

      case ProgressPeriod.allTime:
        periodSessions = await sessionRepo.getAll();
        final completedSessions = periodSessions.where((s) => s.complete).toList();
        if (completedSessions.isEmpty) {
          chartPoints = const [];
          targetMinutes = 0;
          periodWeeks = 1;
        } else {
          final monthBuckets = <String, int>{};
          for (final session in completedSessions) {
            final key = '${session.scheduledDate.year}-${session.scheduledDate.month}';
            monthBuckets[key] = (monthBuckets[key] ?? 0) + (session.actualDuration ?? 0);
          }
          final sortedKeys = monthBuckets.keys.toList()
            ..sort((a, b) {
              final ap = a.split('-').map(int.parse).toList();
              final bp = b.split('-').map(int.parse).toList();
              return DateTime(ap[0], ap[1]).compareTo(DateTime(bp[0], bp[1]));
            });
          // Cap to the most recent 6 months so the chart stays readable.
          final shown = sortedKeys.length > 6
              ? sortedKeys.sublist(sortedKeys.length - 6)
              : sortedKeys;
          const monthNames = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          chartPoints = shown.map((key) {
            final month = int.parse(key.split('-')[1]);
            return BarChartPoint(label: monthNames[month - 1], value: monthBuckets[key]!);
          }).toList();

          final firstDate = completedSessions
              .map((s) => s.scheduledDate)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          final daysTracked = now.difference(firstDate).inDays.clamp(1, 100000);
          targetMinutes = (student?.dailyGoalMinutes ?? 0) * daysTracked;
          periodWeeks = daysTracked / 7;
        }
        break;
    }

    if (periodWeeks < 1) periodWeeks = 1;

    final totalMinutes = completedMinutesTotal(periodSessions);

    final subjectPerformance = <Subject, int>{};
    for (final subject in subjects) {
      final subjectMinutes = completedMinutesTotal(
        periodSessions.where((s) => s.subjectId == subject.id).toList(),
      );
      final subjectTarget = subject.weeklyTargetMinutes * periodWeeks;
      final percent = subjectTarget == 0
          ? 0
          : ((subjectMinutes / subjectTarget) * 100).round().clamp(0, 100);
      subjectPerformance[subject] = percent;
    }

    final streak = currentStreak(completedDates, today: now);
    final longest = study_stats.longestStreak(completedDates);

    final insights = generateInsights(
      todayMinutes: completedMinutesForDate(await sessionRepo.getForDate(now), now),
      weeklyMinutes: period == ProgressPeriod.week
          ? totalMinutes
          : completedMinutesTotal(await sessionRepo.getForRange(startOfWeek(now), endOfWeek(now))),
      weeklyGoalMinutes: student?.weeklyGoalMinutes ?? 0,
      streak: streak,
      longestStreak: longest,
      subjectPerformancePercent: {
        for (final entry in subjectPerformance.entries) entry.key.name: entry.value,
      },
    );

    return ProgressViewData(
      period: period,
      totalMinutes: totalMinutes,
      targetMinutes: targetMinutes,
      chartPoints: chartPoints,
      subjectPerformancePercent: subjectPerformance,
      streak: streak,
      longestStreak: longest,
      insights: insights,
    );
  }
}