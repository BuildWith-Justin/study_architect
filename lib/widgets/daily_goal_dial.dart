import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DailyGoalDial extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  final double size;

  static const int minMinutes = 15;
  static const int maxMinutes = 480;
  static const int step = 15;

  const DailyGoalDial({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.size = 260,
  });

  void _update(Offset local) {
    final c = Offset(size / 2, size / 2);
    final d = local - c;
    var angle = math.atan2(d.dx, -d.dy); // 0 at top, clockwise
    if (angle < 0) angle += 2 * math.pi;
    final frac = angle / (2 * math.pi);
    final raw = minMinutes + frac * (maxMinutes - minMinutes);
    var snapped = ((raw / step).round() * step).clamp(minMinutes, maxMinutes);

    // Stop the dial jumping across the top: stick to the end you came from.
    if (minutes > maxMinutes * 0.75 && snapped < maxMinutes * 0.25) {
      snapped = maxMinutes;
    } else if (minutes < maxMinutes * 0.25 && snapped > maxMinutes * 0.75) {
      snapped = minMinutes;
    }
    onChanged(snapped);
  }

  static String format(int m) {
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final track = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.primarySoft;
    final frac = (minutes - minMinutes) / (maxMinutes - minMinutes);

    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onTapDown: (d) => _update(d.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _DialPainter(frac, track),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  format(minutes),
                  style: textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'per day',
                  style: textTheme.bodyMedium?.copyWith(color: secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double frac;
  final Color track;
  _DialPainter(this.frac, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final sweep = 2 * math.pi * frac;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          AppColors.teal,
          AppColors.primary,
          AppColors.teal,
        ],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);

    final a = -math.pi / 2 + sweep;
    final thumb = Offset(
      center.dx + radius * math.cos(a),
      center.dy + radius * math.sin(a),
    );
    canvas.drawCircle(
      thumb,
      stroke * 0.85,
      Paint()..color = AppColors.primary.withValues(alpha: 0.25),
    );
    canvas.drawCircle(thumb, stroke * 0.6, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumb,
      stroke * 0.32,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.frac != frac || old.track != track;
}