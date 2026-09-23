import 'package:flutter/material.dart';

class AppSettings {
  final bool notificationsEnabled;
  final ThemeMode themeMode;

  const AppSettings({
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() => {
        'notificationsEnabled': notificationsEnabled ? 1 : 0,
        'themeMode': themeMode.name,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        notificationsEnabled: (map['notificationsEnabled'] as int) == 1,
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == map['themeMode'],
          orElse: () => ThemeMode.system,
        ),
      );
}