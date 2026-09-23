import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pastel_card.dart';

/// A single task tile, e.g. Home's "Computer networks / Laboratory
/// work N1 / 3 days left" card.
class TaskCard extends StatelessWidget {
  final String subject;
  final String title;
  final String meta; // e.g. "3 days left" or "Until 09.18"
  final PastelHue hue;
  final bool completed;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.subject,
    required this.title,
    required this.meta,
    required this.hue,
    this.completed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strong = pastelStrong(hue);
    return PastelCard(
      hue: hue,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subject,
            style: TextStyle(
              fontSize: 11,
              color: strong.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 13,
                color: strong,
              ),
              const SizedBox(width: 4),
              Text(
                meta,
                style: TextStyle(fontSize: 11, color: strong.withOpacity(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}