import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pastel_card.dart';

/// The hero "Now" card on Home showing the current/next class,
/// with a Join button (used while a session is live).
class ClassCard extends StatelessWidget {
  final String timeRange; // e.g. "8:40 - 10:15"
  final String title; // e.g. "Mathematical analysis"
  final PastelHue hue;
  final String actionLabel; // e.g. "Join the lesson" or "Start session"
  final VoidCallback? onAction;

  const ClassCard({
    super.key,
    required this.timeRange,
    required this.title,
    required this.actionLabel,
    this.hue = PastelHue.blue,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A5F73)),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.videocam_rounded, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}