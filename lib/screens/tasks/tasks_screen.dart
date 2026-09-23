
import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/gradient_background.dart';
import 'tasks_view_data.dart';
import 'add_edit_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _taskRepo = TaskRepository();
  late Future<TasksViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = TasksViewData.load();
  }

  Future<void> _reload() async {
    setState(() {
      _future = TasksViewData.load();
    });

    await _future;
  }

  Future<void> _toggle(Task task) async {
    await _taskRepo.setCompleted(
      task.id,
      !task.completed,
    );

    await _reload();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddEditTaskScreen(),
      ),
    );

    if (!mounted) return;

    await _reload();
  }

  Future<void> _openEdit(Task task) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditTaskScreen(
          existing: task,
        ),
      ),
    );

    if (!mounted) return;

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<TasksViewData>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final data = snapshot.data!;

              final hasAnyTasks =
                  data.overdue.isNotEmpty ||
                  data.today.isNotEmpty ||
                  data.tomorrow.isNotEmpty ||
                  data.upcoming.isNotEmpty;

              return Column(
                children: [
                  AppBar(
                    title: const Text(
                      'Things you need to accomplish',
                    ),
                    leading: const BackButton(),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_rounded,
                        ),
                        onPressed: _openCreate,
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reload,
                      child: !hasAnyTasks
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height *
                                          0.6,
                                  child: Center(
                                    child: Text(
                                      'No tasks yet — tap + to add one.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.all(AppSpacing.lg),
                              children: [
                                if (data.overdue.isNotEmpty)
                                  _TaskGroup(
                                    title: 'Overdue',
                                    tasks: data.overdue,
                                    data: data,
                                    onToggle: _toggle,
                                    onTap: _openEdit,
                                  ),
                                if (data.today.isNotEmpty)
                                  _TaskGroup(
                                    title: 'Today',
                                    tasks: data.today,
                                    data: data,
                                    onToggle: _toggle,
                                    onTap: _openEdit,
                                  ),
                                if (data.tomorrow.isNotEmpty)
                                  _TaskGroup(
                                    title: 'Tomorrow',
                                    tasks: data.tomorrow,
                                    data: data,
                                    onToggle: _toggle,
                                    onTap: _openEdit,
                                  ),
                                if (data.upcoming.isNotEmpty)
                                  _TaskGroup(
                                    title: 'Upcoming',
                                    tasks: data.upcoming,
                                    data: data,
                                    onToggle: _toggle,
                                    onTap: _openEdit,
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final TasksViewData data;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onTap;

  const _TaskGroup({
    required this.title,
    required this.tasks,
    required this.data,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tasks.map((task) {
            final subject = data.subjectsById[task.subjectId];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => onTap(task),
              leading: Checkbox(
                value: task.completed,
                onChanged: (_) => onToggle(task),
                activeColor: subject != null
                    ? Color(subject.colorValue)
                    : AppColors.accentPurpleStrong,
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration: task.completed
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.completed
                      ? AppColors.textSecondary
                      : context.primaryText,
                ),
              ),
              subtitle: Text(
                subject?.name ?? 'Unknown subject',
              ),
            );
          }),
        ],
      ),
    );
  }
}
