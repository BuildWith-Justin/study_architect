import 'package:flutter/material.dart';

import '../models/insight.dart';
import '../screens/tasks/tasks_screen.dart';
import '../services/insights_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';

/// V2 Step 14c: the "Insights" section of the Progress screen.
///
/// Shows every current suggestion as a card. Hides itself when there is
/// nothing to show. Pass a [loadToken] that changes each time the
/// Progress screen reloads (Progress uses identityHashCode(data)).
class AiInsightsSection extends StatefulWidget {
  final int loadToken;

  /// On the Progress screen itself, a "See progress" button would open
  /// Progress again, so those buttons are hidden by default.
  final bool hideProgressAction;

  const AiInsightsSection({
    super.key,
    required this.loadToken,
    this.hideProgressAction = true,
  });

  @override
  State<AiInsightsSection> createState() => _AiInsightsSectionState();
}

class _AiInsightsSectionState extends State<AiInsightsSection> {
  List<Insight> _insights = const [];
  bool _loaded = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AiInsightsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadToken != widget.loadToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final list = await InsightsService.load(limit: 10);
    if (!mounted || generation != _generation) return;
    setState(() {
      _insights = list;
      _loaded = true;
    });
  }

  Future<void> _snooze(Insight insight) async {
    await InsightsService.snooze(insight);
    await _reload();
  }

  Future<void> _runAction(Insight insight) async {
    Widget? screen;
    switch (insight.action) {
      case InsightAction.tasks:
        screen = const TasksScreen();
        break;
      case InsightAction.progress:
      case InsightAction.none:
        break;
    }
    if (screen == null) return;
    final target = screen;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => target),
    );
    if (mounted) await _reload();
  }

  bool _showsAction(Insight insight) {
    if (insight.action == InsightAction.none) return false;
    if (insight.action == InsightAction.progress &&
        widget.hideProgressAction) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _insights.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Insights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Based on your own study history. Nothing leaves your device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final insight in _insights)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight.icon,
                  size: 20,
                  color: AppColors.accentPurpleStrong,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          if (_showsAction(insight)) ...[
                            GestureDetector(
                              onTap: () => _runAction(insight),
                              child: Text(
                                insight.actionLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                          ],
                          GestureDetector(
                            onTap: () => _snooze(insight),
                            child: Text(
                              'Not now',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
