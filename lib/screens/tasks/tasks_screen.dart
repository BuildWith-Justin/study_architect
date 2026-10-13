import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../gamification/gamification_hooks.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/gradient_background.dart';
import 'tasks_view_data.dart';
import 'add_edit_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with RefreshableScreenMixin<TasksScreen> {
  final _taskRepo = TaskRepository();

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.tasks,
        RefreshScope.subjects,
      ];

  @override
  Future<void> onRefresh() => _reload();

  /// The list currently on screen. Held in state (not in a Future) so
  /// every change goes through a plain setState.
  TasksViewData? _data;
  Object? _error;

  /// Ticks the person just made, shown immediately on screen until the
  /// reload from the database confirms them.
  final Map<String, bool> _pending = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Reloads from the database. Called after every action on this
  /// screen and by pull-to-refresh.
  Future<void> _reload() async {
    try {
      final data = await TasksViewData.load();
      if (!mounted) return;
      debugPrint(
        '[Tasks] reload: overdue=${data.overdue.length} today=${data.today.length} '
        'tomorrow=${data.tomorrow.length} upcoming=${data.upcoming.length}',
      );
      setState(() {
        _data = data;
        _error = null;
        _pending.clear();
      });
    } catch (e, st) {
      debugPrint('[Tasks] reload failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        if (_data == null) _error = e;
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    await _reload();
  }

  Future<void> _toggle(Task task) async {
    final newValue = !(_pending[task.id] ?? task.completed);
    debugPrint('[Tasks] toggle ${task.id} -> $newValue');

    // 1) Instant feedback on screen.
    setState(() => _pending[task.id] = newValue);

    // 2) Save to the database.
    try {
      await _taskRepo.setCompleted(task.id, newValue);
      debugPrint('[Tasks] saved ${task.id}');

      // V2 Step 13: XP for a completed task, removed again if un-ticked.
      if (newValue) {
        await GamificationHooks.taskCompleted(task.copyWith(completed: true));
      } else {
        await GamificationHooks.taskRemoved(task.id);
      }
    } catch (e, st) {
      debugPrint('[Tasks] toggle failed: $e\n$st');
      if (!mounted) return;
      setState(() => _pending.remove(task.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the task: $e')),
      );
      return;
    }

    // V2 Step 17: tell Home, Progress and the other screens that tasks changed.
    DataRefreshBus.instance.notify(RefreshScope.tasks);

    // 3) Reload from the database.
    await _reload();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
    );
    await _reload();
  }

  Future<void> _openEdit(Task task) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditTaskScreen(existing: task)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Things you need to accomplish'),
                leading: const BackButton(),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Add a task',
                    onPressed: _openCreate,
                  ),
                ],
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _data;

    if (data == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: context.secondaryText,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Could not load your tasks.',
                  style: TextStyle(color: context.secondaryText),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _retry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return _buildContent(context, data);
  }

  /// The loaded list with the person's not-yet-confirmed ticks applied.
  List<Task> _withPending(List<Task> tasks) {
    return tasks.map((t) {
      final override = _pending[t.id];
      return override == null ? t : t.copyWith(completed: override);
    }).toList();
  }

  Widget _buildContent(BuildContext context, TasksViewData data) {
    final overdue = _withPending(data.overdue);
    final today = _withPending(data.today);
    final tomorrow = _withPending(data.tomorrow);
    final upcoming = _withPending(data.upcoming);

    final hasAnyTasks = overdue.isNotEmpty ||
        today.isNotEmpty ||
        tomorrow.isNotEmpty ||
        upcoming.isNotEmpty;

    if (!hasAnyTasks) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Text(
                  'No tasks yet — tap + to add one.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.secondaryText,
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final pendingCount = [...overdue, ...today, ...tomorrow, ...upcoming]
        .where((t) => !t.completed)
        .length;
    final overdueCount = overdue.where((t) => !t.completed).length;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          24,
        ),
        children: [
          _SummaryLine(pending: pendingCount, overdue: overdueCount),
          const SizedBox(height: AppSpacing.lg),
          if (overdue.isNotEmpty)
            _TaskGroup(
              title: 'Overdue',
              isOverdue: true,
              tasks: overdue,
              subjectsById: data.subjectsById,
              onToggle: _toggle,
              onTap: _openEdit,
            ),
          if (today.isNotEmpty)
            _TaskGroup(
              title: 'Today',
              tasks: today,
              subjectsById: data.subjectsById,
              onToggle: _toggle,
              onTap: _openEdit,
            ),
          if (tomorrow.isNotEmpty)
            _TaskGroup(
              title: 'Tomorrow',
              tasks: tomorrow,
              subjectsById: data.subjectsById,
              onToggle: _toggle,
              onTap: _openEdit,
            ),
          if (upcoming.isNotEmpty)
            _TaskGroup(
              title: 'Upcoming',
              tasks: upcoming,
              subjectsById: data.subjectsById,
              onToggle: _toggle,
              onTap: _openEdit,
            ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final int pending;
  final int overdue;

  const _SummaryLine({required this.pending, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pendingText = pending == 0
        ? 'All caught up'
        : pending == 1
            ? '1 task pending'
            : '$pending tasks pending';

    return Row(
      children: [
        Text(
          pendingText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.secondaryText,
          ),
        ),
        if (overdue > 0) ...[
          Text(
            '  ·  ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.secondaryText,
            ),
          ),
          Text(
            '$overdue overdue',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final String title;
  final bool isOverdue;
  final List<Task> tasks;
  final Map<String, Subject> subjectsById;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onTap;

  const _TaskGroup({
    required this.title,
    this.isOverdue = false,
    required this.tasks,
    required this.subjectsById,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${tasks.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? AppColors.danger : null,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TaskTile(
                key: ValueKey(task.id),
                task: task,
                subject: subjectsById[task.subjectId],
                onToggle: () => onToggle(task),
                onTap: () => onTap(task),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final Subject? subject;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TaskTile({
    super.key,
    required this.task,
    required this.subject,
    required this.onToggle,
    required this.onTap,
  });

  static String _typeLabel(TaskType type) {
    switch (type) {
      case TaskType.assignment:
        return 'Assignment';
      case TaskType.reading:
        return 'Reading';
      case TaskType.revision:
        return 'Revision';
      case TaskType.project:
        return 'Project';
      case TaskType.other:
        return 'Task';
    }
  }

  static String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final dueDay = DateTime.utc(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;

    if (diff < 0) return diff == -1 ? '1 day overdue' : '${-diff} days overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${weekdays[due.weekday - 1]}, ${months[due.month - 1]} ${due.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        subject != null ? Color(subject!.colorValue) : AppColors.primary;
    final isOverdue =
        !task.completed && task.dueDate.isBefore(startOfDay(DateTime.now()));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: context.cardSurfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.cardSmall),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Checkbox(
                value: task.completed,
                onChanged: (_) => onToggle(),
                activeColor: accent,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed
                            ? context.secondaryText
                            : context.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${subject?.name ?? 'Unknown subject'} · ${_typeLabel(task.type)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                task.completed ? 'Done' : _dueLabel(task.dueDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOverdue ? AppColors.danger : context.secondaryText,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
