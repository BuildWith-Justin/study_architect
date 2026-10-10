import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pastel_card.dart';

/// The hero "Now" card on Home showing the current/next class.
/// The action button (for example "Start session") only appears when an
/// [actionLabel] and an [onAction] are given, i.e. while a session is live.
class ClassCard extends StatelessWidget {
  final String timeRange; // e.g. "8:40 - 10:15"
  final String title; // e.g. "Mathematical analysis"
  final PastelHue hue;
  final String? actionLabel; // e.g. "Start session"
  final VoidCallback? onAction;

  const ClassCard({
    super.key,
    required this.timeRange,
    required this.title,
    this.actionLabel,
    this.hue = PastelHue.blue,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final timeColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF5A5F73);
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    final label = actionLabel;
    final action = onAction;
    final showButton = label != null && action != null;

    return PastelCard(
      hue: hue,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeRange,
            style: TextStyle(fontSize: 12, color: timeColor),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: titleColor,
            ),
          ),
          if (showButton) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
