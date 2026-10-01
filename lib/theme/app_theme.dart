import 'package:flutter/material.dart';

/// Design tokens for Study Architect V2 (teal-green + navy reference sheet).
/// Single source of truth for colours. Estimated from the reference image:
/// adjust the hex values here and the whole app follows.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF16A37F);
  static const primaryDark = Color(0xFF0E8A6B);
  static const primarySoft = Color(0xFFD9F2EA);
  static const teal = Color(0xFF1FD0B5);

  // Page background gradients
  static const backgroundGradientTop = Color(0xFFF1F7F6);
  static const backgroundGradientBottom = Color(0xFFE4EEF2);
  static const darkBackgroundGradientTop = Color(0xFF0F1B2E);
  static const darkBackgroundGradientBottom = Color(0xFF0A1220);

  // Surfaces
  static const surfaceLight = Color(0xFFF7FAFA);
  static const surfaceLightAlt = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF16233A);
  static const surfaceDarkAlt = Color(0xFF1B2A44);

  // Tinted cards (classes, tasks, timetable events)
  static const accentBlue = Color(0xFFDCE9FB);
  static const accentPurple = Color(0xFFE9E1FA);
  static const accentGreen = Color(0xFFD6F1E6);

  // Saturated versions (timeline dots, charts, subject colours)
  static const accentBlueStrong = Color(0xFF4C8DF6);
  static const accentPurpleStrong = Color(0xFF8B6FE0);
  static const accentGreenStrong = Color(0xFF1FB57F);

  // Text
  static const textPrimary = Color(0xFF14213D);
  static const textSecondary = Color(0xFF6B7A90);
  static const textPrimaryDark = Color(0xFFEAF1FA);
  static const textSecondaryDark = Color(0xFF93A4BE);

  // Nav bar
  static const navInactive = Color(0xFFA9B5C4);
  static const navInactiveDark = Color(0xFF56657F);

  // Destructive actions
  static const danger = Color(0xFFD64545);

  // Theme-aware helpers
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;
  static Color primaryText(BuildContext c) =>
      isDark(c) ? textPrimaryDark : textPrimary;
  static Color secondaryText(BuildContext c) =>
      isDark(c) ? textSecondaryDark : textSecondary;
  static Color card(BuildContext c) =>
      isDark(c) ? surfaceDarkAlt : surfaceLightAlt;
}

class AppRadii {
  AppRadii._();
  static const outer = 24.0;
  static const card = 16.0;
  static const cardSmall = 14.0;
  static const control = 10.0;
  static const button = 14.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}