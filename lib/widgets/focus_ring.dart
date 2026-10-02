import 'dart:math' as math;
import 'package:flutter/material.dart';

/// V2 Step 8b: circular progress ring drawn with a CustomPainter.
///
/// [fraction] is how much of the ring is filled, from 0.0 (empty) to
/// 1.0 (full circle). The arc starts at the top and runs clockwise.
/// [child] is shown in the middle (the countdown text).
class FocusRing extends StatelessWidget {
  final double size;
  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final Widget? child;

  const FocusRing({
    super.key,
    required this.size,
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 14,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FocusRingPainter(
          fraction: fraction,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _FocusRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Background track (the full circle).
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final safeFraction = fraction.clamp(0.0, 1.0);
    if (safeFraction <= 0) return;

    // Progress arc, starting at 12 o'clock.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * safeFraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter old) {
    return old.fraction != fraction ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.strokeWidth != strokeWidth;
  }
}
