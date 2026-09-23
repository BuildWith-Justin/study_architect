
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../repositories/settings_repository.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance =
      NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _settingsRepo = SettingsRepository();

  bool _initialized = false;

  static const _dailyReminderId = 999999;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timezoneInfo.identifier),
      );
    } catch (_) {
      // Falls back to UTC if the device timezone cannot be determined.
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings();

    const windowsInit = WindowsInitializationSettings(
      appName: 'Study Architect',
      appUserModelId: 'StudyArchitect.StudyArchitect',
      guid: '7c9f8e21-4b6a-4f3c-9d12-8e5a6b7c4d21',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        windows: windowsInit,
      ),
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<bool> _notificationsEnabled() async {
    final settings = await _settingsRepo.get();
    return settings.notificationsEnabled;
  }

  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String subjectName,
    required DateTime sessionStart,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    if (!await _notificationsEnabled()) return;

    await init();

    final fireTime = sessionStart.subtract(leadTime);

    if (fireTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _sessionNotificationId(sessionId),
      title: 'Upcoming study session',
      body: '$subjectName starts in ${leadTime.inMinutes} minutes.',
      scheduledDate: tz.TZDateTime.from(
        fireTime,
        tz.local,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'session_reminders',
          'Session reminders',
          channelDescription:
              'Reminders before a planned study session starts.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelSessionReminder(
    String sessionId,
  ) async {
    await init();

    await _plugin.cancel(
      id: _sessionNotificationId(sessionId),
    );
  }

  Future<void> scheduleDailyGoalReminder(
    TimeOfDay time,
  ) async {
    if (!await _notificationsEnabled()) return;

    await init();

    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(
        const Duration(days: 1),
      );
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Daily study goal',
      body:
          "Don't forget today's study goal — even a short session keeps your streak alive.",
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goal_reminders',
          'Daily goal reminders',
          channelDescription:
              'A daily nudge to hit your study goal.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyGoalReminder() async {
    await init();

    await _plugin.cancel(
      id: _dailyReminderId,
    );
  }

  int _sessionNotificationId(String sessionId) {
    return sessionId.hashCode & 0x7fffffff;
  }
}
