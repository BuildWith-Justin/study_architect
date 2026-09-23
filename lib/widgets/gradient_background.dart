import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps a screen's content in the soft diagonal pastel gradient used
/// on every screen. Switches to the dedicated dark gradient in dark mode.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = isDark
        ? AppColors.darkBackgroundGradientTop
        : AppColors.backgroundGradientTop;
    final bottom = isDark
        ? AppColors.darkBackgroundGradientBottom
        : AppColors.backgroundGradientBottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      child: child,
    );
  }
}