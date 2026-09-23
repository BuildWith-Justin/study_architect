import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shorthand for the isDark-branch pattern already used in
/// StatCard/ProgressCard since Step 2 — lets every other screen pick
/// up the same "dedicated dark scheme, not just inverted" behavior
/// without repeating `Theme.of(context).brightness == Brightness.dark`
/// everywhere.
///
/// Deliberately NOT used inside form input fields (TextField /
/// DropdownButtonFormField fill colors and their typed-text color) —
/// those stay a fixed light surface with fixed dark text in both
/// themes, since that was a specific, already-debugged fix and
/// switching it per-theme risks reintroducing invisible typed text.
extension ThemeAwareColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Plain info/stat card background — e.g. a settings row, a summary
  /// box. Not for pastel accent cards, which stay the same hue in
  /// both themes by design.
  Color get cardSurface => isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;

  Color get cardSurfaceAlt => isDarkMode ? AppColors.surfaceDarkAlt : AppColors.surfaceLightAlt;

  /// Body text sitting on a [cardSurface] (not on a pastel card, and
  /// not typed text inside a form field).
  Color get primaryText => isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

  Color get secondaryText => isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary;
}