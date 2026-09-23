import '../../models/subject.dart';
import '../../models/task.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/task_repository.dart';
import '../../utils/date_utils.dart';

/// All tasks bucketed the way the Tasks screen displays them, plus
/// subject lookups for each task's colored tag.
class TasksViewData {
  final List<Task> overdue;
  final List<Task> today;
  final List<Task> tomorrow;
  final List<Task> upcoming;
  final Map<String, Subject> subjectsById;

  const TasksViewData({
    required this.overdue,
    required this.today,
    required this.tomorrow,
    required this.upcoming,
    required this.subjectsById,
  });

  static Future<TasksViewData> load() async {
    final taskRepo = TaskRepository();
    final subjectRepo = SubjectRepository();

    final allTasks = await taskRepo.getAll();
    final subjects = await subjectRepo.getAll();
    final subjectsById = {for (final s in subjects) s.id: s};

    final now = DateTime.now();
    final today = startOfDay(now);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfterTomorrow = today.add(const Duration(days: 2));

    // Completed tasks stay visible in their original bucket (crossed
    // out) rather than disappearing, so finishing something today
    // doesn't make it look like it vanished.
    final pending = allTasks;

    final overdueList = pending
        .where((t) => !t.completed && t.dueDate.isBefore(today))
        .toList();
    final todayList = pending
        .where((t) => isSameDay(t.dueDate, today))
        .toList();
    final tomorrowList = pending
        .where((t) => isSameDay(t.dueDate, tomorrow))
        .toList();
    final upcomingList = pending
        .where((t) => t.dueDate.isAfter(dayAfterTomorrow) || isSameDay(t.dueDate, dayAfterTomorrow))
        .toList();

    for (final list in [overdueList, todayList, tomorrowList, upcomingList]) {
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }

    return TasksViewData(
      overdue: overdueList,
      today: todayList,
      tomorrow: tomorrowList,
      upcoming: upcomingList,
      subjectsById: subjectsById,
    );
  }
}