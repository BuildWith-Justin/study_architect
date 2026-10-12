import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The tinted hues used across Home tasks, class cards, Subjects and
/// Timetable events. blue / purple / green are the original three;
/// orange, pink and red match the extra subject colours.
enum PastelHue { blue, purple, green, orange, pink, red }

Color pastelBackground(PastelHue hue) {
  switch (hue) {
    case PastelHue.blue:
      return AppColors.accentBlue;
    case PastelHue.purple:
      return AppColors.accentPurple;
    case PastelHue.green:
      return AppColors.accentGreen;
    case PastelHue.orange:
      return const Color(0xFFFFEFD2);
    case PastelHue.pink:
      return const Color(0xFFFCE4F0);
    case PastelHue.red:
      return const Color(0xFFFDE2E2);
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
    case PastelHue.orange:
      // Slightly deeper than the swatch so text stays readable on the card.
      return const Color(0xFFD97706);
    case PastelHue.pink:
      return const Color(0xFFEC4899);
    case PastelHue.red:
      return const Color(0xFFEF4444);
  }
}

/// Picks the card hue for a subject's saved colour. Unknown / older
/// colours (including the old purple) fall back to purple.
PastelHue pastelHueForColor(int colorValue) {
  if (colorValue == AppColors.accentBlueStrong.toARGB32()) {
    return PastelHue.blue;
  }
  if (colorValue == AppColors.accentGreenStrong.toARGB32()) {
    return PastelHue.green;
  }
  switch (colorValue) {
    case 0xFFF59E0B:
      return PastelHue.orange;
    case 0xFFEC4899:
      return PastelHue.pink;
    case 0xFFEF4444:
      return PastelHue.red;
    default:
      return PastelHue.purple;
  }
}

/// Generic tinted container: the base every task/class/event card builds
/// on. Light mode: soft pastel. Dark mode: the strong hue at low opacity
/// over the navy background, so light text stays readable.
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
    final isDark = AppColors.isDark(context);
    final bg = isDark
        ? pastelStrong(hue).withValues(alpha: 0.18)
        : pastelBackground(hue);

    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
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
