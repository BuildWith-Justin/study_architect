import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single topic line on the Subject detail screen — checkbox plus
/// name, struck through once completed.
class TopicRow extends StatelessWidget {
  final String name;
  final bool completed;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDelete;

  const TopicRow({
    super.key,
    required this.name,
    required this.completed,
    required this.onChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          Checkbox(
            value: completed,
            onChanged: onChanged,
            activeColor: AppColors.accentPurpleStrong,
          ),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed
                    ? AppColors.textSecondary
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}