import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pastel_card.dart';

/// Subject row on the Subjects screen: initial badge, name, topic
/// count, and completion percentage.
class SubjectCard extends StatelessWidget {
  final String name;
  final int topicCount;
  final int completionPercent;
  final PastelHue hue;
  final VoidCallback? onTap;

  const SubjectCard({
    super.key,
    required this.name,
    required this.topicCount,
    required this.completionPercent,
    required this.hue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strong = pastelStrong(hue);
    return PastelCard(
      hue: hue,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: strong,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$topicCount topics',
                  style: TextStyle(fontSize: 12, color: strong.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          Text(
            '$completionPercent%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: strong,
            ),
          ),
        ],
      ),
    );
  }
}