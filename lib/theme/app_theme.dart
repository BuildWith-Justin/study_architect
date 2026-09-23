import 'package:flutter/material.dart';

/// Design tokens for Study Architect, sampled from the approved
/// pastel "Hello, Paul" reference UI. Keep this file as the single
/// source of truth for colors so light/dark themes and every screen
/// stay consistent.
class AppColors {
  AppColors._();

  // Background gradient (page-level, behind the floating white card).
  static const backgroundGradientTop = Color(0xFFCFDBF5);
  static const backgroundGradientBottom = Color(0xFFC5D0EC);

  // Dark-mode background gradient — dedicated dark surface, not an
  // inverted light theme.
  static const darkBackgroundGradientTop = Color(0xFF1B1D2B);
  static const darkBackgroundGradientBottom = Color(0xFF15161F);

  // Card / sheet surfaces.
  static const surfaceLight = Color(0xFFFAFAFA);
  static const surfaceLightAlt = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF23253A);
  static const surfaceDarkAlt = Color(0xFF2A2C42);

  // Pastel accent cards — used for classes, tasks, and timetable events.
  static const accentBlue = Color(0xFFDCE7FB);
  static const accentPurple = Color(0xFFEBDAF7);
  static const accentGreen = Color(0xFFD2F2D8);

  // Saturated versions of the same three hues, for timeline dots,
  // charts, and active-state accents.
  static const accentBlueStrong = Color(0xFF6B8FE0);
  static const accentPurpleStrong = Color(0xFF9B7FD4);
  static const accentGreenStrong = Color(0xFF5FCB7A);

  // Text.
  static const textPrimary = Color(0xFF2A2A33);
  static const textSecondary = Color(0xFF8A8A93);
  static const textPrimaryDark = Color(0xFFEDEDF2);
  static const textSecondaryDark = Color(0xFFA6A6B3);

  // Nav bar.
  static const navInactive = Color(0xFFB5B5BD);
  static const navInactiveDark = Color(0xFF5C5E70);
}

class AppRadii {
  AppRadii._();
  static const outer = 24.0;
  static const card = 16.0;
  static const cardSmall = 14.0;
  static const control = 10.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}