import 'package:flutter/material.dart';
import '../../app/route_observer.dart';
import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../gamification/gamification_engine.dart';
import '../../gamification/xp_rules.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/ai_suggestion_card.dart';
import '../../widgets/class_card.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/schedule_row.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/task_card.dart';
import '../../widgets/user_avatar.dart';
import '../achievements/achievements_screen.dart';
import '../progress/progress_screen.dart';
import '../session/focus_timer_screen.dart';
import '../tasks/add_edit_task_screen.dart';
import '../tasks/tasks_screen.dart';
import '../timetable/timetable_screen.dart';
import 'home_view_data.dart';
import 'next_exam_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        WidgetsBindingObserver,
        RouteAware,
        RefreshableScreenMixin<HomeScreen> {
  late Future<HomeViewData> _future;

  ModalRoute<dynamic>? _route;

  /// Data scopes that should make Home reload itself automatically.
  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.sessions,
        RefreshScope.tasks,
        RefreshScope.subjects,
        RefreshScope.achievements,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
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
    super.dispose(); // RefreshableScreenMixin cancels its subscription here.
  }

  @override
  void didPopNext() {
    onRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onRefresh();
    }
  }

  /// Used by pull-to-refresh, the DataRefreshBus, returning from another
  /// screen and app resume.
  @override
  Future<void> onRefresh() async {
    final next = HomeViewData.load();

    if (!mounted) {
      next.ignore();
      return;
    }

    setState(() {
      _future = next;
    });

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

  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );

    if (mounted) {
      await onRefresh();
    }
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
          return buildRefreshable(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    'Could not load your dashboard.\nPull down to try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final now = DateTime.now();
        final weekStart = startOfWeek(now);
        final weekDays = List<DateTime>.generate(
          7,
          (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
        );

        return buildRefreshable(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Extra bottom space so the last card is not hidden behind
            // the floating bottom navigation bar.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(
                  greeting: _greeting(),
                  name: data.student.name,
                  avatarPath: data.student.avatarPath,
                ),
                const SizedBox(height: AppSpacing.lg),
                GestureDetector(
                  onTap: () => _openScreen(const AchievementsScreen()),
                  child: _LevelXpCard(snapshot: data.gamification),
                ),
                const SizedBox(height: AppSpacing.md),
                _TodayProgressCard(
                  current: formatDuration(data.todayMinutes),
                  target: formatDuration(data.dailyGoalMinutes),
                  percent: data.todayProgress,
                  note: data.todayProgress >= 1
                      ? 'Goal reached! Great work.'
                      : 'Keep going! ${(data.todayProgress * 100).round()}%',
                ),
                const SizedBox(height: AppSpacing.md),
                _StreakStrip(
                  streak: data.streak,
                  weekDays: weekDays,
                  today: now,
                  studiedOn: data.studiedOn,
                  bridgedOn: data.bridgedOn,
                  bonusActive: data.streak >= XpRules.streakBonusMinStreak,
                  freezeUsed: data.freezeUsed,
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
                      child: GestureDetector(
                        onTap: () => _openScreen(const TasksScreen()),
                        child: StatCard(
                          label: 'Tasks today',
                          value: '${data.tasksTodayCount}',
                          showsTapAffordance: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openScreen(const ProgressScreen()),
                        child: StatCard(
                          label: 'Weekly goal',
                          value: '${data.weeklyGoalPercent}%',
                          showsTapAffordance: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                NextExamCard(loadToken: identityHashCode(data)),
                AiSuggestionCard(loadToken: identityHashCode(data)),
                const SizedBox(height: AppSpacing.lg),
                if (_currentOrNextSession(data) != null) ...[
                  _buildClassCard(data),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.todayTasks.isNotEmpty) ...[
                  _SectionHeader(
                    title: "Today's tasks",
                    onViewAll: () => _openScreen(const TasksScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.todayTasks.take(3).map((task) {
                    final subject = data.subjectsById[task.subjectId];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TaskCard(
                        subject: subject?.name ?? 'Unknown subject',
                        title: task.title,
                        meta: task.completed ? 'Done' : 'Due today',
                        hue: _hueForSubject(subject),
                        completed: task.completed,
                        onTap: () => _openScreen(
                          AddEditTaskScreen(existing: task),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.todaySessions.isNotEmpty) ...[
                  _SectionHeader(
                    title: "Today's schedule",
                    onViewAll: () => _openScreen(
                      const TimetableScreen(standalone: true),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.todaySessions.map((session) {
                    final subject = data.subjectsById[session.subjectId];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ScheduleRow(
                        title: subject?.name ?? 'Unknown subject',
                        timeRange:
                            '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
                        accent: subject != null
                            ? Color(subject.colorValue)
                            : AppColors.primary,
                      ),
                    );
                  }),
                ] else
                  Text(
                    'No sessions scheduled today — tap + to plan one.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.secondaryText,
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
      actionLabel: isLive ? 'Start session' : null,
      onAction: isLive
          ? () => _openScreen(
                FocusTimerScreen(
                  subjectId: session.subjectId,
                  subjectName: subject?.name ?? 'Unknown subject',
                  subjectColorValue:
                      subject?.colorValue ?? AppColors.accentPurpleStrong.value,
                  topicId: session.topicId,
                  existingSessionId: session.id,
                  goal: session.endTime.difference(session.startTime),
                ),
              )
          : null,
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

    return pastelHueForColor(color);

  }
}

class _SessionAndSubject {
  final StudySession session;
  final Subject? subject;

  const _SessionAndSubject(this.session, this.subject);
}

/// "Good morning" + student name, with the profile photo (or the initial
/// when there is no photo yet).
class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String? avatarPath;

  const _HomeHeader({
    required this.greeting,
    required this.name,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        UserAvatar(name: name, avatarPath: avatarPath, size: 48),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Level, XP progress and today's XP (V2 step 13d). Tappable: opens the
/// Achievements screen, which the arrow on the right hints at.
// 13e-chevron
class _LevelXpCard extends StatelessWidget {
  final GamificationSnapshot? snapshot;

  const _LevelXpCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = snapshot;
    final level = snap?.level;

    var title = 'Level & XP';
    var xpText = '';
    var detail = '';
    if (snap != null && level != null) {
      title = 'Level ${level.level} · ${levelTitle(level.level)}';
      if (level.isMax) {
        xpText = '${level.totalXp} XP';
        detail = 'Max level reached';
      } else {
        xpText = '${level.xpIntoLevel} / ${level.levelSize} XP';
        final today =
            snap.xpToday > 0 ? '+${snap.xpToday} XP today' : 'Study to earn XP';
        detail = '$today · ${level.xpToNext} XP to Level ${level.level + 1}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: level == null
                ? const Icon(Icons.bolt_rounded, color: AppColors.primary)
                : Text(
                    '${level.level}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      xpText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: level?.progress ?? 0,
                    minHeight: 6,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            color: context.secondaryText,
          ),
        ],
      ),
    );
  }
}

/// Green hero card: studied time today vs the daily goal.
class _TodayProgressCard extends StatelessWidget {
  final String current;
  final String target;
  final double percent;
  final String note;

  const _TodayProgressCard({
    required this.current,
    required this.target,
    required this.percent,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final softWhite = Colors.white.withValues(alpha: 0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Today's progress",
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ $target',
                style: theme.textTheme.bodyMedium?.copyWith(color: softWhite),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
        ],
      ),
    );
  }
}

/// Current streak plus the 7 days of this week (Monday to Sunday).
/// A filled day has 10+ minutes studied; a snowflake is a missed day that
/// the weekly freeze forgave.
class _StreakStrip extends StatelessWidget {
  final int streak;
  final List<DateTime> weekDays;
  final DateTime today;
  final bool Function(DateTime day) studiedOn;
  final bool Function(DateTime day) bridgedOn;
  final bool bonusActive;
  final bool freezeUsed;

  const _StreakStrip({
    required this.streak,
    required this.weekDays,
    required this.today,
    required this.studiedOn,
    required this.bridgedOn,
    required this.bonusActive,
    required this.freezeUsed,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = streak == 0
        ? 'Start your streak today'
        : streak == 1
            ? '1 day streak'
            : '$streak day streak';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (bonusActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+${XpRules.streakBonusPercent}% XP',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) => _dayCell(context, i)),
          ),
          if (streak > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              freezeUsed
                  ? 'Missed-day freeze used this week'
                  : 'One missed day per week is forgiven',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, int index) {
    final day = weekDays[index];
    final studied = studiedOn(day);
    final bridged = !studied && bridgedOn(day);
    final isToday = isSameDay(day, today);

    final neutralFill = context.isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.08);

    return Column(
      children: [
        Text(
          _labels[index],
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: studied ? AppColors.primary : neutralFill,
            border: isToday && !studied
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: studied
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : bridged
                  ? const Icon(
                      Icons.ac_unit_rounded,
                      size: 16,
                      color: AppColors.primary,
                    )
                  : null,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View all',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                ),
          ),
        ),
      ],
    );
  }
}
