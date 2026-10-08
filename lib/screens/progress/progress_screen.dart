import 'package:flutter/material.dart';

import '../../app/route_observer.dart';
import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_builder.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/ai_insights_section.dart';
import '../../widgets/study_bar_chart.dart';
import 'progress_view_data.dart';
import 'weekly_report_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with RouteAware, RefreshableScreenMixin<ProgressScreen> {
  ProgressPeriod _period = ProgressPeriod.week;
  late Future<ProgressViewData> _future;

  ModalRoute<dynamic>? _route;
  bool _isRefreshing = false;
  bool _refreshQueued = false;

  /// Data scopes that make this screen reload itself automatically.
  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.sessions,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
    _future = ProgressViewData.load(_period);
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
    super.dispose(); // RefreshableScreenMixin cancels its subscription here.
  }

  @override
  void didPopNext() {
    // A screen that was above Progress has just closed, so data may
    // have changed.
    onRefresh();
  }

  void _selectPeriod(ProgressPeriod period) {
    if (_period == period) return;

    setState(() {
      _period = period;
      _future = ProgressViewData.load(period);
    });
  }

  /// Used by pull-to-refresh, the DataRefreshBus and returning from
  /// another screen. A refresh requested while one is already running
  /// is queued and runs right after, so the screen never ends up stale.
  @override
  Future<void> onRefresh() async {
    if (!mounted) return;

    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;

    try {
      do {
        _refreshQueued = false;

        final next = ProgressViewData.load(_period);

        if (!mounted) {
          next.ignore();
          return;
        }

        setState(() => _future = next);

        try {
          await next;
        } catch (_) {
          // AsyncBuilder shows the error state.
        }
      } while (_refreshQueued && mounted);
    } finally {
      _isRefreshing = false;
    }
  }

  String _periodLabel(ProgressPeriod period) {
    switch (period) {
      case ProgressPeriod.week:
        return 'Weekly study time';
      case ProgressPeriod.month:
        return 'Monthly study time';
      case ProgressPeriod.allTime:
        return 'All-time study time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Progress'),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WeeklyReportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: const Text('Weekly report'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                leading: const BackButton(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your study performance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ProgressPeriod>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primarySoft,
                            selectedForegroundColor: AppColors.primaryDark,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: ProgressPeriod.week,
                              label: Text('Week'),
                            ),
                            ButtonSegment(
                              value: ProgressPeriod.month,
                              label: Text('Month'),
                            ),
                            ButtonSegment(
                              value: ProgressPeriod.allTime,
                              label: Text('All time'),
                            ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (s) => _selectPeriod(s.first),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: AsyncBuilder<ProgressViewData>(
                          future: _future,
                          errorMessage: 'Could not load your progress.',
                          onRetry: () => onRefresh(),
                          builder: (context, data) {
                            return buildRefreshable(
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  _SummaryCard(
                                    data: data,
                                    label: _periodLabel(_period),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (data.subjectPerformancePercent
                                      .isNotEmpty) ...[
                                    Text(
                                      'Subject performance',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _SubjectPerformanceCard(data: data),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  _StreakCard(data: data),
                                  AiInsightsSection(
                                      loadToken: identityHashCode(data)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Total time, target, percent of target and the bar chart.
class _SummaryCard extends StatelessWidget {
  final ProgressViewData data;
  final String label;

  const _SummaryCard({required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = data.targetMinutes == 0
        ? null
        : (data.totalMinutes / data.targetMinutes * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.secondaryText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDuration(data.totalMinutes),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (percent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Text(
                    '$percent% of target',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            'Target: ${formatDuration(data.targetMinutes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.chartPoints.isNotEmpty)
            StudyBarChart(
              points: data.chartPoints,
              highlightIndex: data.period == ProgressPeriod.week
                  ? DateTime.now().weekday - 1
                  : null,
            ),
          if (data.chartPoints.isEmpty || data.totalMinutes == 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No completed sessions yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One progress bar per subject, in the subject's own colour.
class _SubjectPerformanceCard extends StatelessWidget {
  final ProgressViewData data;

  const _SubjectPerformanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final trackColor = context.isDarkMode
        ? AppColors.surfaceDarkAlt
        : AppColors.backgroundGradientTop;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: data.subjectPerformancePercent.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${entry.value}%'),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / 100,
                    minHeight: 6,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation(
                      Color(entry.key.colorValue),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Current streak and longest streak.
class _StreakCard extends StatelessWidget {
  final ProgressViewData data;

  const _StreakCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${data.streak} day streak',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Longest: ${data.longestStreak} days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
