import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../repositories/settings_repository.dart';
import 'app_prefs.dart';
import 'database_service.dart';

/// One planned exam reminder: kind is 'eve' (day before, 18:00) or
/// 'day' (exam morning, 07:30).
class ExamReminderSlot {
  final String kind;
  final DateTime at;
  const ExamReminderSlot(this.kind, this.at);
}

/// Pure function (no plugin, no database), so it can be unit-tested.
/// Only slots that are still in the future are returned.
List<ExamReminderSlot> planExamReminders(DateTime exam, DateTime now) {
  final day = DateTime(exam.year, exam.month, exam.day);
  final slots = <ExamReminderSlot>[
    ExamReminderSlot('eve', DateTime(day.year, day.month, day.day - 1, 18, 0)),
    ExamReminderSlot('day', DateTime(day.year, day.month, day.day, 7, 30)),
  ];
  return slots.where((s) => s.at.isAfter(now)).toList();
}

/// Re-applies reminders every time the app comes back to the foreground
/// (covers timezone changes and exams added or edited meanwhile).
class _LifecycleHook with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.applyAllSafe();
    }
  }
}

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _settingsRepo = SettingsRepository();
  final _lifecycleHook = _LifecycleHook();

  bool _initialized = false;
  bool _applying = false;
  bool _applyAgain = false;

  static const _dailyReminderId = 999999;
  static const _testNotificationId = 999998;
  static const _examPayloadPrefix = 'exam:';
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _examDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'exam_reminders',
      'Exam reminders',
      channelDescription:
          'Reminders the evening before and the morning of an exam.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _refreshTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

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
    WidgetsBinding.instance.addObserver(_lifecycleHook);
  }

  Future<void> _refreshTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Keeps the previous (or UTC) timezone if the device one is unknown.
    }
  }

  // ------------------------------------------------------------ permission

  Future<void> requestPermissions() async {
    await init();

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

  /// true / false on Android, null where the app cannot tell (iOS, desktop).
  Future<bool?> permissionGranted() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return null;
    return android.areNotificationsEnabled();
  }

  /// Asks the system for permission, then reports the result (null = unknown).
  Future<bool?> requestPermissionAndCheck() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? await android.areNotificationsEnabled();
    }
    await requestPermissions();
    return null;
  }

  Future<bool> _notificationsEnabled() async {
    final settings = await _settingsRepo.get();
    return settings.notificationsEnabled;
  }

  // ------------------------------------------------------- master switch

  /// Saves the master switch, then schedules or cancels everything.
  Future<void> setMasterEnabled(bool enabled) async {
    final current = await _settingsRepo.get();
    await _settingsRepo.save(current.copyWith(notificationsEnabled: enabled));
    if (enabled) {
      await applyAll();
    } else {
      await cancelAllReminders();
    }
  }

  Future<void> cancelAllReminders() async {
    await init();
    await _plugin.cancelAll();
  }

  // ------------------------------------------------------------ sessions

  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String subjectName,
    required DateTime sessionStart,
    Duration? leadTime,
  }) async {
    if (!await _notificationsEnabled()) return;

    final prefs = await AppPrefs.loadNotificationPrefs();
    if (!prefs.sessionEnabled) return;

    await init();

    final lead = leadTime ?? Duration(minutes: prefs.sessionLeadMinutes);
    final fireTime = sessionStart.subtract(lead);

    if (fireTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _sessionNotificationId(sessionId),
      title: 'Upcoming study session',
      body: '$subjectName starts in ${lead.inMinutes} minutes.',
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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

  // --------------------------------------------------------- daily goal

  /// Schedules the repeating daily reminder. The time chosen in
  /// Settings wins over [time]; [time] is only the default when the
  /// user never picked one. Does nothing (and cancels) if the daily
  /// reminder is switched off.
  Future<void> scheduleDailyGoalReminder(
    TimeOfDay time,
  ) async {
    if (!await _notificationsEnabled()) return;

    final prefs = await AppPrefs.loadNotificationPrefs();

    await init();

    if (!prefs.dailyEnabled) {
      await _plugin.cancel(id: _dailyReminderId);
      return;
    }

    final at = prefs.dailyTime ?? time;
    final goal = await _dailyGoalMinutes();

    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      at.hour,
      at.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(
        const Duration(days: 1),
      );
    }

    final body = goal == null
        ? "Don't forget today's study goal. Even a short session keeps your streak alive."
        : "Today's goal: ${_formatMinutes(goal)}. Even a short session keeps your streak alive.";

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Daily study goal',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goal_reminders',
          'Daily goal reminders',
          channelDescription: 'A daily nudge to hit your study goal.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyGoalReminder() async {
    await init();

    await _plugin.cancel(
      id: _dailyReminderId,
    );
  }

  Future<int?> _dailyGoalMinutes() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT dailyGoalMinutes AS m FROM students LIMIT 1',
      );
      if (rows.isEmpty) return null;
      final v = rows.first['m'];
      return v is int ? v : int.tryParse('$v');
    } catch (_) {
      return null;
    }
  }

  String _formatMinutes(int m) {
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  // -------------------------------------------------------------- exams

  /// Rebuilds the exam reminders from the exams table: the evening
  /// before (18:00) and the morning of the exam (07:30).
  Future<void> rescheduleExamReminders() async {
    if (!await _notificationsEnabled()) return;

    await init();
    await _cancelExamReminders();

    final prefs = await AppPrefs.loadNotificationPrefs();
    if (!prefs.examEnabled) return;

    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT e.id AS id, e.title AS title, e.examDate AS examDate, '
      's.name AS subjectName '
      'FROM exams e LEFT JOIN subjects s ON s.id = e.subjectId',
    );

    final now = DateTime.now();

    for (final row in rows) {
      final id = row['id']?.toString();
      final rawDate = row['examDate']?.toString();
      if (id == null || rawDate == null) continue;

      var exam = DateTime.tryParse(rawDate);
      if (exam == null) continue;
      if (exam.isUtc) exam = exam.toLocal();

      final title = (row['title']?.toString() ?? '').trim();
      final label = title.isEmpty ? 'your exam' : title;
      final subject = (row['subjectName']?.toString() ?? '').trim();
      final dateLabel = '${_monthNames[exam.month - 1]} ${exam.day}';

      for (final slot in planExamReminders(exam, now)) {
        final isEve = slot.kind == 'eve';
        try {
          await _plugin.zonedSchedule(
            id: _examNotificationId(id, slot.kind),
            title: isEve ? 'Exam tomorrow: $label' : 'Exam today: $label',
            body: isEve
                ? '${subject.isEmpty ? '' : '$subject - '}$dateLabel. '
                    'Time for a last review.'
                : 'Good luck! You have prepared for this.',
            scheduledDate: tz.TZDateTime.from(slot.at, tz.local),
            notificationDetails: _examDetails,
            payload: '$_examPayloadPrefix$id',
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('Could not schedule exam reminder: $e');
        }
      }
    }
  }

  Future<void> _cancelExamReminders() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload != null && payload.startsWith(_examPayloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('Could not clear exam reminders: $e');
    }
  }

  int _examNotificationId(String examId, String kind) {
    return ('exam:$examId:$kind').hashCode & 0x7fffffff;
  }

  // ------------------------------------------------------------ apply all

  /// Brings every reminder in line with the settings: master switch,
  /// daily reminder, exam reminders. Safe to call at any time.
  Future<void> applyAll() async {
    if (_applying) {
      _applyAgain = true;
      return;
    }
    _applying = true;
    try {
      do {
        _applyAgain = false;
        await _applyOnce();
      } while (_applyAgain);
    } finally {
      _applying = false;
    }
  }

  /// Same as [applyAll] but never throws (used at startup and on resume).
  Future<void> applyAllSafe() async {
    try {
      await applyAll();
    } catch (e) {
      debugPrint('Reminder refresh failed: $e');
    }
  }

  Future<void> _applyOnce() async {
    await init();
    await _refreshTimezone();

    final settings = await _settingsRepo.get();
    if (!settings.notificationsEnabled) {
      await _plugin.cancel(id: _dailyReminderId);
      await _cancelExamReminders();
      return;
    }

    // Nothing to remind about before onboarding is finished.
    if (!await _hasStudent()) return;

    final prefs = await AppPrefs.loadNotificationPrefs();
    if (prefs.dailyEnabled) {
      await scheduleDailyGoalReminder(prefs.effectiveDailyTime);
    } else {
      await _plugin.cancel(id: _dailyReminderId);
    }

    await rescheduleExamReminders();
  }

  Future<bool> _hasStudent() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM students');
    final c = rows.first['c'];
    return (c is int ? c : int.tryParse('$c') ?? 0) > 0;
  }

  // ----------------------------------------------------------------- test

  Future<void> showTestNotification() async {
    await init();

    await _plugin.show(
      id: _testNotificationId,
      title: 'Study Architect',
      body: 'Notifications are working. Good luck with your studies!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_notifications',
          'Test notifications',
          channelDescription: 'Used by the "Send a test" button.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  int _sessionNotificationId(String sessionId) {
    return sessionId.hashCode & 0x7fffffff;
  }
}
