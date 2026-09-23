import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

/// Single source of truth for the app's current ThemeMode. MaterialApp
/// listens to [mode] directly, so calling [setMode] anywhere in the
/// app (from the More/Settings screen) updates every screen
/// immediately — no restart needed.
class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  final _settingsRepo = SettingsRepository();

  Future<void> loadFromSettings() async {
    final settings = await _settingsRepo.get();
    mode.value = settings.themeMode;
  }

  Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    final current = await _settingsRepo.get();
    await _settingsRepo.save(current.copyWith(themeMode: newMode));
  }
}