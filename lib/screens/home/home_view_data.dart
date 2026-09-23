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
  });

  double get todayProgress =>
      dailyGoalMinutes == 0 ? 0 : (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);

  int get weeklyGoalPercent =>
      weeklyGoalMinutes == 0 ? 0 : ((weeklyMinutes / weeklyGoalMinutes) * 100).round();

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
      throw StateError('HomeViewData.load() called before onboarding completed.');
    }

    final subjects = await subjectRepo.getAll();
    final subjectsById = {for (final s in subjects) s.id: s};

    final todaySessions = await sessionRepo.getForDate(now);
    final weekSessions = await sessionRepo.getForRange(weekStart, weekEnd);
    final todayTasks = await taskRepo.getForDate(now);
    final completedDates = await sessionRepo.getCompletedDates();

    return HomeViewData(
      student: student,
      todayMinutes: completedMinutesForDate(todaySessions, now),
      dailyGoalMinutes: student.dailyGoalMinutes,
      weeklyMinutes: completedMinutesTotal(weekSessions),
      weeklyGoalMinutes: student.weeklyGoalMinutes,
      subjectsCount: subjects.length,
      tasksTodayCount: todayTasks.where((t) => !t.completed).length,
      streak: currentStreak(completedDates, today: now),
      todaySessions: todaySessions,
      subjectsById: subjectsById,
      todayTasks: todayTasks,
    );
  }
}