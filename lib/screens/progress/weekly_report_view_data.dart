import '../../gamification/gamification_engine.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/study_stats.dart';
import '../../widgets/simple_bar_chart.dart';

/// Minutes studied for one subject during the report week.
class SubjectMinutes {
  final Subject subject;
  final int minutes;

  const SubjectMinutes({required this.subject, required this.minutes});
}

/// Everything the Weekly Report screen needs, loaded in one pass.
class WeeklyReportViewData {
  final DateTime weekStart;
  final int totalMinutes;
  final int lastWeekMinutes;
  final int goalMinutes;
  final int completedSessions;
  final int totalSessions;
  final int lastWeekCompletedSessions;
  final List<BarChartPoint> dayPoints;

  /// 0 = Monday ... 6 = Sunday, or -1 when nothing was studied.
  final int bestDayIndex;
  final SubjectMinutes? topSubject;
  final List<SubjectMinutes> subjectBreakdown;
  final double? averageRating;
  final int streak;

  const WeeklyReportViewData({
    required this.weekStart,
    required this.totalMinutes,
    required this.lastWeekMinutes,
    required this.goalMinutes,
    required this.completedSessions,
    required this.totalSessions,
    required this.lastWeekCompletedSessions,
    required this.dayPoints,
    required this.bestDayIndex,
    required this.topSubject,
    required this.subjectBreakdown,
    required this.averageRating,
    required this.streak,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  int get deltaMinutes => totalMinutes - lastWeekMinutes;

  bool get goalReached => goalMinutes > 0 && totalMinutes >= goalMinutes;

  int get goalPercent =>
      goalMinutes == 0 ? 0 : ((totalMinutes / goalMinutes) * 100).round();

  String get bestDayLabel => bestDayIndex < 0 ? '-' : _dayNames[bestDayIndex];

  String get weekRangeLabel {
    final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final startMonth = _months[weekStart.month - 1];
    if (weekStart.month == end.month) {
      return '$startMonth ${weekStart.day} - ${end.day}';
    }
    return '$startMonth ${weekStart.day} - ${_months[end.month - 1]} ${end.day}';
  }

  String get summaryLine {
    if (totalMinutes == 0 && lastWeekMinutes == 0) {
      return 'No study time logged yet. Complete a session to start your report.';
    }
    final diff = deltaMinutes;
    final String compare;
    if (diff > 0) {
      compare = 'You studied ${formatDuration(diff)} more than last week.';
    } else if (diff < 0) {
      compare = 'You studied ${formatDuration(-diff)} less than last week.';
    } else {
      compare = 'Same study time as last week.';
    }
    return goalReached ? '$compare Weekly goal reached.' : compare;
  }

  static Future<WeeklyReportViewData> load() async {
    final sessionRepo = SessionRepository();
    final subjectRepo = SubjectRepository();
    final studentRepo = StudentRepository();

    final now = DateTime.now();
    final weekStart = startOfWeek(now);
    final weekEnd = endOfWeek(now);
    final lastWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );

    final student = await studentRepo.getCurrent();
    final subjects = await subjectRepo.getAll();
    final subjectsById = {for (final s in subjects) s.id: s};
    final all = await sessionRepo.getForRange(lastWeekStart, weekEnd);

    // The repository range is inclusive at both ends, so filter again
    // here to keep each week strictly [start, nextStart).
    bool inRange(StudySession s, DateTime a, DateTime b) =>
        !s.scheduledDate.isBefore(a) && s.scheduledDate.isBefore(b);

    final thisWeek = all.where((s) => inRange(s, weekStart, weekEnd)).toList();
    final lastWeek =
        all.where((s) => inRange(s, lastWeekStart, weekStart)).toList();

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dayPoints = List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      return BarChartPoint(
        label: labels[i],
        value: completedMinutesForDate(thisWeek, day),
      );
    });

    var bestDayIndex = -1;
    var bestValue = 0;
    for (var i = 0; i < dayPoints.length; i++) {
      if (dayPoints[i].value > bestValue) {
        bestValue = dayPoints[i].value;
        bestDayIndex = i;
      }
    }

    final minutesBySubject = <String, int>{};
    final ratings = <int>[];
    for (final s in thisWeek.where((s) => s.complete)) {
      minutesBySubject[s.subjectId] =
          (minutesBySubject[s.subjectId] ?? 0) + (s.actualDuration ?? 0);
      if (s.rating != null) ratings.add(s.rating!);
    }

    final breakdown = <SubjectMinutes>[];
    for (final entry in minutesBySubject.entries) {
      final subject = subjectsById[entry.key];
      if (subject != null && entry.value > 0) {
        breakdown.add(SubjectMinutes(subject: subject, minutes: entry.value));
      }
    }
    breakdown.sort((a, b) => b.minutes.compareTo(a.minutes));

    final averageRating = ratings.isEmpty
        ? null
        : ratings.fold<int>(0, (sum, r) => sum + r) / ratings.length;

    return WeeklyReportViewData(
      weekStart: weekStart,
      totalMinutes: completedMinutesTotal(thisWeek),
      lastWeekMinutes: completedMinutesTotal(lastWeek),
      goalMinutes: student?.weeklyGoalMinutes ?? 0,
      completedSessions: thisWeek.where((s) => s.complete).length,
      totalSessions: thisWeek.length,
      lastWeekCompletedSessions: lastWeek.where((s) => s.complete).length,
      dayPoints: dayPoints,
      bestDayIndex: bestDayIndex,
      topSubject: breakdown.isEmpty ? null : breakdown.first,
      subjectBreakdown: breakdown,
      averageRating: averageRating,
      streak: (await GamificationEngine.instance.getStreakInfo(now: now))
          .current
          .length,
    );
  }
}
