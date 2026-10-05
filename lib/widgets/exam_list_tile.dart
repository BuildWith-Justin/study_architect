import 'package:flutter/material.dart';

import '../models/exam.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import '../utils/exam_format.dart';

/// One row of the exams list: title, subject and date, prep progress
/// and a days-left chip that changes color as the exam gets closer.
class ExamListTile extends StatelessWidget {
  final String title;
  final String subjectName;
  final Color accent;
  final String dateLabel;
  final int daysLeft;
  final ExamProgress progress;
  final VoidCallback onTap;

  const ExamListTile({
    super.key,
    required this.title,
    required this.subjectName,
    required this.accent,
    required this.dateLabel,
    required this.daysLeft,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgencyColor = examUrgencyColor(context, examUrgency(daysLeft));

    return Material(
      color: context.cardSurfaceAlt,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subjectName \u00B7 $dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.fraction,
                              minHeight: 5,
                              backgroundColor: accent.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          progress.total == 0
                              ? 'No topics'
                              : '${progress.prepared}/${progress.total}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  daysLeftLabel(daysLeft),
                  style: TextStyle(
                    color: urgencyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
