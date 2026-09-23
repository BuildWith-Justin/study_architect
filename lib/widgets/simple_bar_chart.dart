import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BarChartPoint {
  final String label;
  final int value; // minutes

  const BarChartPoint({required this.label, required this.value});
}

/// A minimal vertical bar chart, no charting package required — used
/// for "Study Hours" on the Progress screen. Bars scale relative to
/// the largest value in [points].
class SimpleBarChart extends StatelessWidget {
  final List<BarChartPoint> points;
  final double height;

  const SimpleBarChart({super.key, required this.points, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(1, (m, p) => p.value > m ? p.value : m);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: points.map((point) {
          final barHeight = (point.value / maxValue) * (height - 24);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: barHeight.clamp(2, height - 24),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: point.value == 0
                        ? AppColors.surfaceLight
                        : AppColors.accentPurpleStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  point.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}