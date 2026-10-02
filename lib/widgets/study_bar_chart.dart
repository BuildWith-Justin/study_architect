import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import '../utils/date_utils.dart';
import 'simple_bar_chart.dart';

/// V2 Step 10a: fl_chart bar chart for study time (values are minutes).
///
/// Takes the same [BarChartPoint] list as the old SimpleBarChart, so the
/// existing ProgressViewData does not need to change. Shows grid lines,
/// time labels on the left, rounded bars and a tap tooltip.
/// [highlightIndex] draws one bar darker (for example today).
class StudyBarChart extends StatelessWidget {
  final List<BarChartPoint> points;
  final double height;
  final int? highlightIndex;

  const StudyBarChart({
    super.key,
    required this.points,
    this.height = 200,
    this.highlightIndex,
  });

  /// Grid step candidates in minutes. The smallest one that keeps the
  /// chart to about 5 grid lines is used.
  static const _steps = [30, 60, 120, 180, 300, 600, 1200, 3000, 6000];

  static int _stepFor(int maxMinutes) {
    for (final step in _steps) {
      if (maxMinutes <= step * 5) return step;
    }
    return _steps.last;
  }

  @override
  Widget build(BuildContext context) {
    final maxMinutes = points.fold<int>(
      0,
      (m, p) => p.value > m ? p.value : m,
    );
    final step = _stepFor(maxMinutes);
    // Always leave some headroom above the tallest bar.
    final maxY = (((maxMinutes ~/ step) + 1) * step).toDouble();

    final gridColor = context.secondaryText.withValues(alpha: 0.18);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.secondaryText,
        );
    final barWidth = points.length > 8 ? 10.0 : 18.0;

    final groups = List.generate(points.length, (i) {
      final isHighlight = highlightIndex == i;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: points[i].value.toDouble(),
            width: barWidth,
            color: isHighlight ? AppColors.primaryDark : AppColors.primary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(5),
            ),
          ),
        ],
      );
    });

    return Semantics(
      label: 'Study time bar chart',
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            barGroups: groups,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step.toDouble(),
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: gridColor, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(points[i].label, style: labelStyle),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final text =
                        value == 0 ? '0' : formatDuration(value.round());
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        text,
                        textAlign: TextAlign.right,
                        style: labelStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.primaryDark,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    formatDuration(rod.toY.round()),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
