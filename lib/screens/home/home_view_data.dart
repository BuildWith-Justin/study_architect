import '../../gamification/gamification_engine.dart';
import '../../models/student.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/task.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/task_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/study_stats.dart';

/// Everything the Home screen needs, loaded in one pass so the UI
/// never has to juggle five separate FutureBuilders.
class HomeViewData {
  final Student student;
  final int todayMinutes;
  final int dailyGoalMinutes;
  final int weeklyMinutes;
  final int weeklyGoalMinutes;
  final int subjectsCount;
  final int tasksTodayCount;
  final int streak;
  final List<StudySession> todaySessions;
  final Map<String, Subject> subjectsById;
  final List<Task> todayTasks;

  /// Days (yyyy-MM-dd) with at least one completed session. Powers the
  /// 7-day streak strip on Home (V2 step 6).
  final Set<String> completedDates;

  /// V2 Step 13: level, XP and the streak (null if the engine failed, in
  /// which case Home falls back to the old streak).
  final GamificationSnapshot? gamification;

  const HomeViewData({
    required this.student,
    required this.todayMinutes,
    required this.dailyGoalMinutes,
    required this.weeklyMinutes,
    required this.weeklyGoalMinutes,
    required this.subjectsCount,
    required this.tasksTodayCount,
    required this.streak,
    required this.todaySessions,
    required this.subjectsById,
    required this.todayTasks,
    this.completedDates = const <String>{},
    this.gamification,
  });

  double get todayProgress => dailyGoalMinutes == 0
      ? 0
      : (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);

  int get weeklyGoalPercent => weeklyGoalMinutes == 0
      ? 0
      : ((weeklyMinutes / weeklyGoalMinutes) * 100).round();

  /// True when [day] counts for the streak (10+ minutes studied). Falls
  /// back to "at least one completed session" if the engine failed.
  bool studiedOn(DateTime day) {
    final g = gamification;
    if (g != null) return g.studyDays.contains(_dateKey(day));
    return completedDates.contains(_dateKey(day));
  }

  /// True when the weekly freeze forgave the missed [day].
  bool bridgedOn(DateTime day) =>
      gamification?.streak.bridgedDays.contains(_dateKey(day)) ?? false;

  /// True when this week's free missed day has already been used.
  bool get freezeUsed => gamification?.streak.freezeUsedThisWeek ?? false;

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<HomeViewData> load() async {
    final studentRepo = StudentRepository();
    final subjectRepo = SubjectRepository();
    final sessionRepo = SessionRepository();
    final taskRepo = TaskRepository();

    final now = DateTime.now();
    final weekStart = startOfWeek(now);
    final weekEnd = endOfWeek(now);

    final student = await studentRepo.getCurrent();
    if (student == null) {
      throw StateError(
          'HomeViewData.load() called before onboarding completed.');
    }

    final subjects = await subjectRepo.getAll();
    final subjectsById = {for (final s in subjects) s.id: s};

    final todaySessions = await sessionRepo.getForDate(now);
    final weekSessions = await sessionRepo.getForRange(weekStart, weekEnd);
    final todayTasks = await taskRepo.getForDate(now);
    final completedDates = await sessionRepo.getCompletedDates();

    // V2 Step 13: level, XP and the new streak. If the engine fails, Home
    // still loads.
    GamificationSnapshot? gamification;
    try {
      gamification = await GamificationEngine.instance.getSnapshot(now: now);
    } catch (_) {
      gamification = null;
    }

    return HomeViewData(
      student: student,
      todayMinutes: completedMinutesForDate(todaySessions, now),
      dailyGoalMinutes: student.dailyGoalMinutes,
      weeklyMinutes: completedMinutesTotal(weekSessions),
      weeklyGoalMinutes: student.weeklyGoalMinutes,
      subjectsCount: subjects.length,
      tasksTodayCount: todayTasks.where((t) => !t.completed).length,
      streak: gamification?.streak.length ??
          currentStreak(completedDates, today: now),
      todaySessions: todaySessions,
      subjectsById: subjectsById,
      todayTasks: todayTasks,
      completedDates: completedDates,
      gamification: gamification,
    );
  }
}
