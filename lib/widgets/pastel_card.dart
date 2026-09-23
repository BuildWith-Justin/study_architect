import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The three pastel hues used across Home tasks, class cards, and
/// Timetable events. Keeping this as an enum means every widget that
/// needs "pick a pastel" pulls from the same three options.
enum PastelHue { blue, purple, green }

Color pastelBackground(PastelHue hue) {
  switch (hue) {
    case PastelHue.blue:
      return AppColors.accentBlue;
    case PastelHue.purple:
      return AppColors.accentPurple;
    case PastelHue.green:
      return AppColors.accentGreen;
  }
}

Color pastelStrong(PastelHue hue) {
  switch (hue) {
    case PastelHue.blue:
      return AppColors.accentBlueStrong;
    case PastelHue.purple:
      return AppColors.accentPurpleStrong;
    case PastelHue.green:
      return AppColors.accentGreenStrong;
  }
}

/// Generic pastel container — the base every task/class/event card
/// builds on top of. Handles the rounded pastel background; callers
/// supply the content.
class PastelCard extends StatelessWidget {
  final PastelHue hue;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PastelCard({
    super.key,
    required this.hue,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: pastelBackground(hue),
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
        onTap: onTap,
        child: card,
      ),
    );
  }
}