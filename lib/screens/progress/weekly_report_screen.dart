import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_builder.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/study_bar_chart.dart';
import 'weekly_report_view_data.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen>
    with RefreshableScreenMixin<WeeklyReportScreen> {
  late Future<WeeklyReportViewData> _future;
  bool _isRefreshing = false;
  bool _refreshQueued = false;

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.sessions,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
    _future = WeeklyReportViewData.load();
  }

  /// Used by pull-to-refresh and the DataRefreshBus. A refresh asked for
  /// while one is already running is queued and runs right after.
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

        final next = WeeklyReportViewData.load();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Weekly report'),
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
                  child: AsyncBuilder<WeeklyReportViewData>(
                    future: _future,
                    errorMessage: 'Could not load your weekly report.',
                    onRetry: () => onRefresh(),
                    builder: (context, data) {
                      return buildRefreshable(
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _HeroCard(data: data),
                            const SizedBox(height: AppSpacing.lg),
                            _ChartCard(data: data),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniStat(
                                    label: 'Sessions',
                                    value:
                                        '${data.completedSessions} of ${data.totalSessions}',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _MiniStat(
                                    label: 'Best day',
                                    value: data.bestDayLabel,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniStat(
                                    label: 'Top subject',
                                    value: data.topSubject?.subject.name ?? '-',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _MiniStat(
                                    label: 'Average rating',
                                    value: data.averageRating == null
                                        ? '-'
                                        : '${data.averageRating!.toStringAsFixed(1)} / 5',
                                  ),
                                ),
                              ],
                            ),
                            if (data.subjectBreakdown.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _SubjectBreakdownCard(data: data),
                            ],
                          ],
                        ),
                      );
                    },
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

/// Week range, total time, change vs last week, goal bar and summary.
class _HeroCard extends StatelessWidget {
  final WeeklyReportViewData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = data.deltaMinutes;
    final showDelta = !(data.totalMinutes == 0 && data.lastWeekMinutes == 0);
    final positive = diff >= 0;
    final sign = diff > 0 ? '+' : '-';
    final deltaText = diff == 0
        ? 'Same as last week'
        : '$sign${formatDuration(diff.abs())} vs last week';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.weekRangeLabel.toUpperCase(),
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
              if (showDelta)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: positive
                        ? AppColors.primarySoft
                        : AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Text(
                    deltaText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          positive ? AppColors.primaryDark : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            'Last week: ${formatDuration(data.lastWeekMinutes)}, '
            '${data.lastWeekCompletedSessions} sessions completed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
          if (data.goalMinutes > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (data.totalMinutes / data.goalMinutes).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: trackColor,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (data.goalReached) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Weekly goal reached',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Text(
                    'Goal: ${formatDuration(data.goalMinutes)} (${data.goalPercent}%)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(data.summaryLine, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Study time per day for the report week.
class _ChartCard extends StatelessWidget {
  final WeeklyReportViewData data;

  const _ChartCard({required this.data});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Study time by day',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          StudyBarChart(
            points: data.dayPoints,
            highlightIndex: DateTime.now().weekday - 1,
          ),
        ],
      ),
    );
  }
}

/// One small label + value tile (long values are cut with an ellipsis).
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Time per subject for the week, bars scaled to the top subject.
class _SubjectBreakdownCard extends StatelessWidget {
  final WeeklyReportViewData data;

  const _SubjectBreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = data.subjectBreakdown.first.minutes;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time by subject',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.subjectBreakdown.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(formatDuration(item.minutes)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : item.minutes / top,
                      minHeight: 6,
                      backgroundColor: trackColor,
                      valueColor: AlwaysStoppedAnimation(
                        Color(item.subject.colorValue),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
