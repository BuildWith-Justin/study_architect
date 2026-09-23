import 'package:flutter/material.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/class_card.dart';
import '../../widgets/task_card.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/schedule_row.dart';
import '../../utils/date_utils.dart';
import '../progress/progress_screen.dart';
import '../session/focus_timer_screen.dart';
import '../tasks/tasks_screen.dart';
import '../tasks/add_edit_task_screen.dart';
import '../timetable/timetable_screen.dart';
import '../../app/route_observer.dart';
import 'home_view_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  late Future<HomeViewData> _future;

  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = HomeViewData.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route != null && route != _route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }

      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final next = HomeViewData.load();

    if (!mounted) {
      return;
    }

    setState(() => _future = next);

    try {
      await next;
    } catch (_) {
      // FutureBuilder handles the error state.
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load your dashboard.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final data = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _reload,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, ${data.student.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                ProgressCard(
                  label: "Today's progress",
                  current: formatDuration(data.todayMinutes),
                  target: formatDuration(data.dailyGoalMinutes),
                  percent: data.todayProgress,
                  note: data.todayProgress >= 1
                      ? "Goal reached! Great work."
                      : 'Keep going! ${(data.todayProgress * 100).round()}%',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Subjects',
                        value: '${data.subjectsCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Tasks today',
                        value: '${data.tasksTodayCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Streak',
                        value: '${data.streak}',
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.accentPurpleStrong,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProgressScreen(),
                            ),
                          );

                          if (mounted) {
                            await _reload();
                          }
                        },
                        child: StatCard(
                          label: 'Weekly goal',
                          value: '${data.weeklyGoalPercent}%',
                          showsTapAffordance: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_currentOrNextSession(data) != null) ...[
                  _buildClassCard(data),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.todayTasks.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's tasks",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TasksScreen(),
                            ),
                          );

                          if (mounted) {
                            await _reload();
                          }
                        },
                        child: Text(
                          'View all',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.accentPurpleStrong,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.todayTasks.take(3).map((task) {
                    final subject = data.subjectsById[task.subjectId];

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TaskCard(
                        subject: subject?.name ?? 'Unknown subject',
                        title: task.title,
                        meta: task.completed ? 'Done' : 'Due today',
                        hue: _hueForSubject(subject),
                        completed: task.completed,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditTaskScreen(
                                existing: task,
                              ),
                            ),
                          );

                          if (mounted) {
                            await _reload();
                          }
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.todaySessions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's schedule",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TimetableScreen(standalone: true),
                            ),
                          );

                          if (mounted) {
                            await _reload();
                          }
                        },
                        child: Text(
                          'View all',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.accentPurpleStrong,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.todaySessions.map((session) {
                    final subject =
                        data.subjectsById[session.subjectId];

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ScheduleRow(
                        title: subject?.name ?? 'Unknown subject',
                        timeRange:
                            '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
                        accent: subject != null
                            ? Color(subject.colorValue)
                            : AppColors.accentPurpleStrong,
                      ),
                    );
                  }),
                ] else
                  Text(
                    'No sessions scheduled today — tap + to plan one.',
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The session currently running, or the next upcoming one today.
  _SessionAndSubject? _currentOrNextSession(HomeViewData data) {
    final now = DateTime.now();

    final sorted = [...data.todaySessions]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final session in sorted) {
      if (session.endTime.isAfter(now)) {
        return _SessionAndSubject(
          session,
          data.subjectsById[session.subjectId],
        );
      }
    }

    return null;
  }

  Widget _buildClassCard(HomeViewData data) {
    final match = _currentOrNextSession(data)!;
    final session = match.session;
    final subject = match.subject;
    final now = DateTime.now();

    final isLive =
        session.startTime.isBefore(now) && session.endTime.isAfter(now);

    return ClassCard(
      timeRange:
          '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
      title: subject?.name ?? 'Unknown subject',
      hue: _hueForSubject(subject),
      actionLabel: isLive ? 'Start session' : 'View details',
      onAction: isLive
          ? () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FocusTimerScreen(
                    subjectId: session.subjectId,
                    subjectName: subject?.name ?? 'Unknown subject',
                    subjectColorValue: subject?.colorValue ??
                        AppColors.accentPurpleStrong.value,
                    topicId: session.topicId,
                    existingSessionId: session.id,
                    goal:
                        session.endTime.difference(session.startTime),
                  ),
                ),
              );

              if (mounted) {
                await _reload();
              }
            }
          : () {},
    );
  }

  PastelHue _hueForSubject(Subject? subject) {
    if (subject == null) {
      return PastelHue.blue;
    }

    final color = subject.colorValue;

    if (color == AppColors.accentGreenStrong.value) {
      return PastelHue.green;
    }

    if (color == AppColors.accentBlueStrong.value) {
      return PastelHue.blue;
    }

    return PastelHue.purple;
  }
}

class _SessionAndSubject {
  final StudySession session;
  final Subject? subject;

  const _SessionAndSubject(this.session, this.subject);
}