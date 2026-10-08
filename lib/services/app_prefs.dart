import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Reminder preferences. They live ONLY on this device (local table
/// app_prefs, never synced) because a reminder time is a per-device choice.
class NotificationPrefs {
  final bool dailyEnabled;

  /// null = the user never picked a time (19:00 is used).
  final TimeOfDay? dailyTime;
  final bool sessionEnabled;
  final int sessionLeadMinutes;
  final bool examEnabled;

  const NotificationPrefs({
    this.dailyEnabled = true,
    this.dailyTime,
    this.sessionEnabled = true,
    this.sessionLeadMinutes = 15,
    this.examEnabled = true,
  });

  TimeOfDay get effectiveDailyTime =>
      dailyTime ?? const TimeOfDay(hour: 19, minute: 0);

  NotificationPrefs copyWith({
    bool? dailyEnabled,
    TimeOfDay? dailyTime,
    bool? sessionEnabled,
    int? sessionLeadMinutes,
    bool? examEnabled,
  }) {
    return NotificationPrefs(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyTime: dailyTime ?? this.dailyTime,
      sessionEnabled: sessionEnabled ?? this.sessionEnabled,
      sessionLeadMinutes: sessionLeadMinutes ?? this.sessionLeadMinutes,
      examEnabled: examEnabled ?? this.examEnabled,
    );
  }
}

/// Tiny key/value store in the local database (table app_prefs).
/// Not part of the cloud sync, so no Supabase change is needed.
class AppPrefs {
  AppPrefs._();

  static const keyDailyEnabled = 'notif.daily.enabled';
  static const keyDailyHour = 'notif.daily.hour';
  static const keyDailyMinute = 'notif.daily.minute';
  static const keySessionEnabled = 'notif.session.enabled';
  static const keySessionLead = 'notif.session.lead';
  static const keyExamEnabled = 'notif.exam.enabled';
  static const keyLastExport = 'backup.lastExportAt';

  static const backupKeys = [
    keyDailyEnabled,
    keyDailyHour,
    keyDailyMinute,
    keySessionEnabled,
    keySessionLead,
    keyExamEnabled,
  ];

  static const leadChoices = [5, 10, 15, 30, 60];

  static bool _tableReady = false;

  static Future<Database> _db() async {
    final db = await DatabaseService.instance.database;
    if (!_tableReady) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS app_prefs '
        '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      _tableReady = true;
    }
    return db;
  }

  static Future<String?> getString(String key) async {
    final db = await _db();
    final rows = await db.query(
      'app_prefs',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  static Future<void> setString(String key, String value) async {
    final db = await _db();
    await db.insert(
      'app_prefs',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<NotificationPrefs> loadNotificationPrefs() async {
    final db = await _db();
    final rows = await db.query('app_prefs', where: "key LIKE 'notif.%'");
    final values = <String, String>{
      for (final r in rows) r['key'] as String: r['value'] as String,
    };

    bool readBool(String key, bool fallback) {
      final v = values[key];
      return v == null ? fallback : v == '1';
    }

    final hour = int.tryParse(values[keyDailyHour] ?? '');
    final minute = int.tryParse(values[keyDailyMinute] ?? '');
    TimeOfDay? time;
    if (hour != null &&
        minute != null &&
        hour >= 0 &&
        hour < 24 &&
        minute >= 0 &&
        minute < 60) {
      time = TimeOfDay(hour: hour, minute: minute);
    }

    final lead = int.tryParse(values[keySessionLead] ?? '');

    return NotificationPrefs(
      dailyEnabled: readBool(keyDailyEnabled, true),
      dailyTime: time,
      sessionEnabled: readBool(keySessionEnabled, true),
      sessionLeadMinutes:
          (lead != null && leadChoices.contains(lead)) ? lead : 15,
      examEnabled: readBool(keyExamEnabled, true),
    );
  }

  static Future<void> saveNotificationPrefs(NotificationPrefs p) async {
    final db = await _db();
    final t = p.effectiveDailyTime;
    final batch = db.batch();

    void put(String key, String value) {
      batch.insert(
        'app_prefs',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    put(keyDailyEnabled, p.dailyEnabled ? '1' : '0');
    put(keyDailyHour, '${t.hour}');
    put(keyDailyMinute, '${t.minute}');
    put(keySessionEnabled, p.sessionEnabled ? '1' : '0');
    put(keySessionLead, '${p.sessionLeadMinutes}');
    put(keyExamEnabled, p.examEnabled ? '1' : '0');
    await batch.commit(noResult: true);
  }

  /// The reminder preferences, as stored (for the backup file).
  static Future<Map<String, String>> exportForBackup() async {
    final db = await _db();
    final rows = await db.query('app_prefs');
    final out = <String, String>{};
    for (final r in rows) {
      final key = r['key'] as String;
      if (backupKeys.contains(key)) out[key] = r['value'] as String;
    }
    return out;
  }

  static Future<void> importFromBackup(Map<String, dynamic> values) async {
    for (final key in backupKeys) {
      final v = values[key];
      if (v is String) await setString(key, v);
    }
  }

  static Future<DateTime?> lastExportAt() async {
    final s = await getString(keyLastExport);
    if (s == null) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  static Future<void> markExportedNow() {
    return setString(keyLastExport, DateTime.now().toUtc().toIso8601String());
  }
}
