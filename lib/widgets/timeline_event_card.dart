import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pastel_card.dart';

/// One event row on the Timetable screen: colored dot + connecting
/// line on the left, pastel event card on the right.
class TimelineEventCard extends StatelessWidget {
  final String timeRange; // e.g. "8:40 - 10:15"
  final String title; // e.g. "Mathematical analysis"
  final String subtitle; // e.g. "Lecture"
  final String meta; // e.g. "Teacher - J.Smith"
  final PastelHue hue;
  final bool isLast;
  final VoidCallback? onTap;

  const TimelineEventCard({
    super.key,
    required this.timeRange,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.hue,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strong = pastelStrong(hue);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: strong,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: strong.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeRange,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  PastelCard(
                    hue: hue,
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: strong.withOpacity(0.85)),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            meta,
                            style: TextStyle(fontSize: 11, color: strong.withOpacity(0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}