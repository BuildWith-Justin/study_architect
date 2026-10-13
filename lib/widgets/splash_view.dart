import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Dark splash shown while the app decides where to go.
/// Shows a Dots Spinner so people can see the app is working.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // On a slow connection the first load can take a while.
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBackgroundGradientTop,
              AppColors.surfaceDarkAlt,
              Color(0xFF3A2E4F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(size: 84),
              const SizedBox(height: AppSpacing.lg),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(text: 'Study '),
                    TextSpan(
                      text: 'Architect',
                      style: TextStyle(color: AppColors.teal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Plan  \u00B7  Study  \u00B7  Achieve',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const Spacer(flex: 2),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(44, 44),
                      painter: _DotsSpinnerPainter(
                        progress: _controller.value,
                        color: AppColors.teal,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _slow
                      ? 'Still working. This can take a moment on a slow '
                          'connection.'
                      : 'Loading...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: Text(
                  'Your personal study companion\nfor a better tomorrow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dots arranged in a circle; a bright "head" runs around the ring and
/// leaves a fading trail behind it.
class _DotsSpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _DotsSpinnerPainter({required this.progress, required this.color});

  static const int _dotCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.shortestSide / 2 - 5;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _dotCount; i++) {
      // 0 = the dot at the head of the trail, close to 1 = end of the trail.
      final behind = ((progress * _dotCount - i) % _dotCount) / _dotCount;
      final strength = 1 - behind;

      paint.color = color.withValues(alpha: 0.2 + 0.8 * strength);
      final radius = 2.2 + 2.2 * strength;

      final angle = -math.pi / 2 + 2 * math.pi * i / _dotCount;
      final offset = Offset(
        center.dx + ringRadius * math.cos(angle),
        center.dy + ringRadius * math.sin(angle),
      );
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
