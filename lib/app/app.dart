import 'package:flutter/material.dart';
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
          routes: AppRoutes.table,
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}