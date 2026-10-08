import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/services/backup_service.dart';
import 'package:study_architect/services/notification_service.dart';

void main() {
  group('planExamReminders', () {
    test('exam in 5 days gives the eve (18:00) and the day (07:30)', () {
      final now = DateTime(2026, 10, 8, 10, 0);
      final slots = planExamReminders(DateTime(2026, 10, 13), now);
      expect(slots.map((s) => s.kind), ['eve', 'day']);
      expect(slots[0].at, DateTime(2026, 10, 12, 18, 0));
      expect(slots[1].at, DateTime(2026, 10, 13, 7, 30));
    });

    test('exam tomorrow: both reminders are still ahead of us', () {
      final now = DateTime(2026, 10, 8, 10, 0);
      final slots = planExamReminders(DateTime(2026, 10, 9), now);
      expect(slots.length, 2);
    });

    test('exam tomorrow but it is already 19:00: only the morning is left', () {
      final now = DateTime(2026, 10, 8, 19, 0);
      final slots = planExamReminders(DateTime(2026, 10, 9), now);
      expect(slots.map((s) => s.kind), ['day']);
    });

    test('exam today after 07:30: nothing is scheduled', () {
      final now = DateTime(2026, 10, 8, 8, 0);
      expect(planExamReminders(DateTime(2026, 10, 8), now), isEmpty);
    });

    test('exam in the past: nothing is scheduled', () {
      final now = DateTime(2026, 10, 8, 8, 0);
      expect(planExamReminders(DateTime(2026, 9, 1), now), isEmpty);
    });

    test('exam on the 1st: the eve is the last day of the previous month', () {
      final now = DateTime(2026, 10, 8, 10, 0);
      final slots = planExamReminders(DateTime(2026, 11, 1), now);
      expect(slots[0].at, DateTime(2026, 10, 31, 18, 0));
    });

    test('exam time of day is ignored (only the date counts)', () {
      final now = DateTime(2026, 10, 8, 10, 0);
      final slots = planExamReminders(DateTime(2026, 10, 13, 14, 30), now);
      expect(slots[1].at, DateTime(2026, 10, 13, 7, 30));
    });
  });

  group('BackupService.parseBackup', () {
    final service = BackupService();

    test('accepts a valid backup', () {
      final parsed = service.parseBackup('{"version": 1, "subjects": []}');
      expect(parsed['version'], 1);
    });

    test('accepts a backup that starts with a BOM', () {
      final parsed = service.parseBackup('\uFEFF{"version": 1}');
      expect(parsed['version'], 1);
    });

    test('rejects text that is not JSON', () {
      expect(() => service.parseBackup('hello'), throwsFormatException);
    });

    test('rejects JSON that is not an object', () {
      expect(() => service.parseBackup('[1, 2, 3]'), throwsFormatException);
    });

    test('rejects a file without a version', () {
      expect(
          () => service.parseBackup('{"subjects": []}'), throwsFormatException);
    });

    test('rejects a version that is not a number', () {
      expect(
          () => service.parseBackup('{"version": "1"}'), throwsFormatException);
    });

    test('rejects a backup made by a newer app', () {
      expect(
          () => service.parseBackup('{"version": 2}'), throwsFormatException);
    });

    test('rejects a damaged section', () {
      expect(() => service.parseBackup('{"version": 1, "tasks": "oops"}'),
          throwsFormatException);
    });

    test('an old backup without V2 sections is still accepted', () {
      final parsed = service.parseBackup(
          '{"version": 1, "student": null, "subjects": [], "topics": []}');
      expect(parsed.containsKey('exams'), isFalse);
    });
  });

  group('BackupService.describe', () {
    final service = BackupService();

    test('counts every section and treats missing ones as zero', () {
      final counts = service.describe({
        'subjects': [1, 2],
        'tasks': [1],
      });
      expect(counts['subjects'], 2);
      expect(counts['tasks'], 1);
      expect(counts['exams'], 0);
      expect(counts['xpLog'], 0);
    });
  });
}
