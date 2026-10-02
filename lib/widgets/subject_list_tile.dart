import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';

/// One subject row on the Subjects list: colored initial badge, name,
/// "N topics · Xh / week", a progress bar and the completion percentage.
class SubjectListTile extends StatelessWidget {
  final String name;
  final int topicCount;
  final int completionPercent;
  final int weeklyTargetMinutes;
  final Color accent;
  final VoidCallback? onTap;

  const SubjectListTile({
    super.key,
    required this.name,
    required this.topicCount,
    required this.completionPercent,
    required this.weeklyTargetMinutes,
    required this.accent,
    this.onTap,
  });

  String get _targetLabel {
    final hours = weeklyTargetMinutes / 60;
    final text = weeklyTargetMinutes % 60 == 0
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '${text}h / week';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = completionPercent.clamp(0, 100) / 100.0;
    final topicsLabel = topicCount == 0
        ? 'No topics yet'
        : topicCount == 1
            ? '1 topic'
            : '$topicCount topics';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.cardSurfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                ),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$topicsLabel  ·  $_targetLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                    if (topicCount > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$completionPercent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
