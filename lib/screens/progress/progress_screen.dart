import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/simple_bar_chart.dart';
import '../../widgets/insight_carousel.dart';
import '../../widgets/async_builder.dart';
import '../../widgets/gradient_background.dart';
import '../../app/route_observer.dart';
import 'progress_view_data.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with RouteAware {
  ProgressPeriod _period = ProgressPeriod.week;
  late Future<ProgressViewData> _future;

  ModalRoute<dynamic>? _route;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  void didPush() {
    // The Progress screen has just become visible.
    _refresh();
  }

  @override
  void didPopNext() {
    // A screen that was above Progress has just closed.
    // Reload immediately because data may have changed.
    _refresh();
  }

  void _selectPeriod(ProgressPeriod period) {
    if (_period == period) {
      return;
    }

    setState(() {
      _period = period;
      _future = ProgressViewData.load(period);
    });
  }

  /// Reloads the progress data from the database.
  ///
  /// This is used by:
  /// - Pull-to-refresh
  /// - Returning to this screen after another route closes
  /// - The initial route activation
  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) {
      return;
    }

    _isRefreshing = true;

    final next = ProgressViewData.load(_period);

    if (!mounted) {
      _isRefreshing = false;
      return;
    }

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // AsyncBuilder handles the error state.
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
                title: const Text('Progress'),
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
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.secondaryText,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<ProgressPeriod>(
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
                        onSelectionChanged: (s) =>
                            _selectPeriod(s.first),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: AsyncBuilder<ProgressViewData>(
                          future: _future,
                          errorMessage: 'Could not load your progress.',
                          onRetry: () => _refresh(),
                          builder: (context, data) {
                            return RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: context.cardSurface,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.card,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _periodLabel(_period)
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.textSecondary,
                                                letterSpacing: 1,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatDuration(
                                            data.totalMinutes,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          'Target: ${formatDuration(data.targetMinutes)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.lg,
                                        ),
                                        if (data.chartPoints.isNotEmpty)
                                          SimpleBarChart(
                                            points: data.chartPoints,
                                          )
                                        else
                                          Text(
                                            'No completed sessions yet.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (data.subjectPerformancePercent
                                      .isNotEmpty) ...[
                                    Text(
                                      'Subject Performance',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(
                                      height: AppSpacing.sm,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.lg,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.cardSurface,
                                        borderRadius:
                                            BorderRadius.circular(
                                          AppRadii.card,
                                        ),
                                      ),
                                      child: Column(
                                        children: data
                                            .subjectPerformancePercent
                                            .entries
                                            .map(
                                          (entry) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          entry.key.name,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width:
                                                            AppSpacing.sm,
                                                      ),
                                                      Text(
                                                        '${entry.value}%',
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                    child:
                                                        LinearProgressIndicator(
                                                      value:
                                                          entry.value / 100,
                                                      minHeight: 6,
                                                      backgroundColor:
                                                          AppColors
                                                              .backgroundGradientTop,
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                        Color(
                                                          entry.key
                                                              .colorValue,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ).toList(),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppSpacing.lg,
                                    ),
                                  ],
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: context.cardSurface,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.card,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons
                                              .local_fire_department_rounded,
                                          color:
                                              AppColors.accentPurpleStrong,
                                        ),
                                        const SizedBox(
                                          width: AppSpacing.sm,
                                        ),
                                        Text(
                                          '${data.streak} day streak',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Longest: ${data.longestStreak} days',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (data.insights.isNotEmpty) ...[
                                    const SizedBox(
                                      height: AppSpacing.lg,
                                    ),
                                    Text(
                                      'Insights',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(
                                      height: AppSpacing.sm,
                                    ),
                                    InsightCarousel(
                                      insights: data.insights,
                                    ),
                                  ],
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
}