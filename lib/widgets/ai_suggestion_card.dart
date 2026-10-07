import 'package:flutter/material.dart';

import '../models/insight.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../services/insights_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import 'quick_add_sheet.dart';

/// V2 Step 14: the "Study suggestion" card on Home.
///
/// Shows the most important pattern-based insight, plus a "Quick add"
/// link that opens the natural-language quick-add sheet. Pass a
/// [loadToken] that changes every time Home reloads (Home uses
/// identityHashCode(data)), so the card refreshes together with Home.
class AiSuggestionCard extends StatefulWidget {
  final int loadToken;

  const AiSuggestionCard({super.key, required this.loadToken});

  @override
  State<AiSuggestionCard> createState() => _AiSuggestionCardState();
}

class _AiSuggestionCardState extends State<AiSuggestionCard> {
  List<Insight> _insights = const [];
  int _index = 0;
  bool _loaded = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AiSuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadToken != widget.loadToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final list = await InsightsService.load();
    // Ignore results that arrive after a newer reload started.
    if (!mounted || generation != _generation) return;
    setState(() {
      _insights = list;
      if (_index >= list.length) _index = 0;
      _loaded = true;
    });
  }

  Future<void> _snoozeCurrent() async {
    if (_insights.isEmpty) return;
    await InsightsService.snooze(_insights[_index]);
    await _reload();
  }

  Future<void> _openQuickAdd() async {
    final created = await showQuickAddSheet(context);
    if (created && mounted) await _reload();
  }

  Future<void> _runAction(Insight insight) async {
    Widget? screen;
    switch (insight.action) {
      case InsightAction.progress:
        screen = const ProgressScreen();
        break;
      case InsightAction.tasks:
        screen = const TasksScreen();
        break;
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

  @override
  Widget build(BuildContext context) {
    // Nothing on the very first frame, so the card does not flash.
    if (!_loaded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasInsight = _insights.isNotEmpty;
    final insight = hasInsight ? _insights[_index] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teal.withValues(alpha: 0.18),
            ),
            child: Icon(
              insight?.icon ?? Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Study suggestion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasInsight)
                      InkWell(
                        onTap: _snoozeCurrent,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: context.secondaryText,
                            semanticLabel: 'Not now',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                if (insight == null)
                  Text(
                    "You're on track. Suggestions will appear here as you study.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.secondaryText,
                    ),
                  )
                else ...[
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
                      if (insight.action != InsightAction.none)
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
                      const Spacer(),
                      if (_insights.length > 1)
                        GestureDetector(
                          onTap: () => setState(() {
                            _index = (_index + 1) % _insights.length;
                          }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_index + 1} of ${_insights.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.secondaryText,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: context.secondaryText,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _openQuickAdd,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quick add a session or task',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
