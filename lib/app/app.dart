import 'package:flutter/material.dart';
import '../features/auth/auth_gate.dart';
import '../theme/light_theme.dart';
import '../theme/dark_theme.dart';
import 'routes.dart';
import 'theme_controller.dart';
import 'route_observer.dart';

class StudyArchitectApp extends StatefulWidget {
  const StudyArchitectApp({super.key});

  @override
  State<StudyArchitectApp> createState() => _StudyArchitectAppState();
}

class _StudyArchitectAppState extends State<StudyArchitectApp> {
  @override
  void initState() {
    super.initState();

    // Loads the saved theme preference (if onboarding has already
    // happened) so the app opens in the right mode instead of
    // flashing system default first.
    ThemeController.instance.loadFromSettings();
  }

  /// V2: wraps the existing root route in AuthGate.
  /// - Signed in (or Supabase unavailable) -> the original root screen,
  ///   exactly what V1 showed.
  /// - Signed out -> Sign In screen.
  /// Every other route in AppRoutes.table is left untouched.
  Map<String, WidgetBuilder> _buildRoutes() {
    final originalRoot = AppRoutes.table[AppRoutes.root];

    if (originalRoot == null) {
      return AppRoutes.table;
    }

    return {
      ...AppRoutes.table,
      AppRoutes.root: (context) => AuthGate(
            signedInBuilder: (gateContext) => originalRoot(gateContext),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Study Architect',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeMode,
          initialRoute: AppRoutes.root,
          routes: _buildRoutes(),
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}