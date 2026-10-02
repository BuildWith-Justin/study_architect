import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';

/// One step of a subject's study roadmap: checkbox, "Step N" caption,
/// topic name, delete button and a drag handle.
///
/// Must be used as a direct item of a ReorderableListView that has
/// buildDefaultDragHandles: false, because the handle uses
/// ReorderableDragStartListener with [index].
class RoadmapTopicTile extends StatelessWidget {
  final int index; // 0-based position in the roadmap
  final String name;
  final bool completed;
  final bool isNext;
  final Color accent;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RoadmapTopicTile({
    super.key,
    required this.index,
    required this.name,
    required this.completed,
    required this.isNext,
    required this.accent,
    required this.onChanged,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepLabel =
        isNext ? 'Up next  ·  Step ${index + 1}' : 'Step ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
        border: Border.all(
          color: isNext ? accent.withValues(alpha: 0.7) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.cardSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Row(
              children: [
                Checkbox(
                  value: completed,
                  onChanged: onChanged,
                  activeColor: accent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isNext ? accent : context.secondaryText,
                            fontWeight:
                                isNext ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration:
                                completed ? TextDecoration.lineThrough : null,
                            color: completed
                                ? context.secondaryText
                                : context.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.secondaryText,
                  tooltip: 'Delete topic',
                  onPressed: onDelete,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: context.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
