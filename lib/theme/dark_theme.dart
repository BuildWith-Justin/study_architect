import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimaryDark,
    displayColor: AppColors.textPrimaryDark,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.darkBackgroundGradientTop,
    textTheme: textTheme,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accentPurpleStrong,
      secondary: AppColors.accentBlueStrong,
      surface: AppColors.surfaceDark,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceDarkAlt,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimaryDark,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDarkAlt,
      selectedItemColor: AppColors.textPrimaryDark,
      unselectedItemColor: AppColors.navInactiveDark,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceDarkAlt,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
  );
}