import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/gamification/badge_defs.dart';
import 'package:study_architect/gamification/streak_calculator.dart';
import 'package:study_architect/gamification/xp_rules.dart';
import 'package:study_architect/models/study_session.dart';

Set<String> keys(List<DateTime> days) => days.map(dayKey).toSet();

StudySession session(DateTime day, int minutes, {bool complete = true}) {
  return StudySession(
    id: '${day.toIso8601String()}-$minutes',
    subjectId: 's1',
    scheduledDate: day,
    startTime: day.add(const Duration(hours: 9)),
    endTime: day.add(const Duration(hours: 10)),
    actualDuration: minutes,
    complete: complete,
  );
}

void main() {
  group('XP rules', () {
    test('session XP: nothing under 5 minutes, 1 XP per minute after', () {
      expect(sessionBaseXp(null), 0);
      expect(sessionBaseXp(4), 0);
      expect(sessionBaseXp(5), 5);
      expect(sessionBaseXp(25), 25);
    });

    test('streak bonus starts at a 3-day streak', () {
      expect(applyStreakBonus(25, 2), 25);
      expect(applyStreakBonus(25, 3), 28);
      expect(applyStreakBonus(0, 10), 0);
    });
  });

  group('Levels', () {
    test('thresholds', () {
      expect(levelForXp(0).level, 1);
      expect(levelForXp(99).level, 1);
      expect(levelForXp(100).level, 2);
      expect(levelForXp(249).level, 2);
      expect(levelForXp(250).level, 3);
      expect(levelForXp(500).level, 4);
      expect(levelForXp(900).level, 5);
      expect(xpForLevel(10), 6050);
      expect(xpForLevel(11), 8050);
    });

    test('progress inside a level', () {
      final info = levelForXp(140);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 40);
      expect(info.levelSize, 150);
      expect(info.xpToNext, 110);
      expect(info.progress, closeTo(40 / 150, 0.0001));
    });

    test('level 50 is the top', () {
      final info = levelForXp(1000000);
      expect(info.level, 50);
      expect(info.isMax, isTrue);
      expect(info.progress, 1.0);
    });
  });

  group('Streak', () {
    // Oct 5 2026 is a Monday.
    final sun = DateTime(2026, 10, 4);
    final mon = DateTime(2026, 10, 5);
    final tue = DateTime(2026, 10, 6);
    final wed = DateTime(2026, 10, 7);

    test('a day needs 10 minutes in total', () {
      final days = qualifyingDays([
        session(mon, 6),
        session(mon, 6),
        session(tue, 9),
        session(wed, 30, complete: false),
      ]);
      expect(days, {dayKey(mon)});
    });

    test('today not studied yet does not break the streak', () {
      final r = streakAsOf(keys([sun, mon, tue]), wed);
      expect(r.length, 3);
    });

    test('today counts once studied', () {
      final r = streakAsOf(keys([sun, mon, tue, wed]), wed);
      expect(r.length, 4);
    });

    test('one missed day in a week is forgiven', () {
      final days = keys([
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        sun,
        mon,
        tue,
      ]);
      final r = streakAsOf(days, tue);
      expect(r.length, 5);
      expect(r.bridgedDays, {dayKey(DateTime(2026, 10, 3))});
    });

    test('two missed days in a row break the streak', () {
      final days = keys([
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
        tue,
      ]);
      final r = streakAsOf(days, tue);
      expect(r.length, 1);
      expect(r.bridgedDays, isEmpty);
    });

    test('only one forgiven day per week', () {
      // Week of Mon Sep 28: studied Mon, Wed, Fri; Tue and Thu missed.
      final days = keys([
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 2),
      ]);
      final r = streakAsOf(days, DateTime(2026, 10, 2));
      expect(r.length, 2);
      expect(r.bridgedDays, {dayKey(DateTime(2026, 10, 1))});
      expect(r.freezeUsedThisWeek, isTrue);
    });

    test('best streak ever', () {
      final days = keys([
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
        tue,
      ]);
      expect(bestStreak(days), 3);
    });
  });

  group('Badges', () {
    test('ids are unique', () {
      final ids = kBadges.map((b) => b.id).toSet();
      expect(ids.length, kBadges.length);
    });

    test('unlock from stats', () {
      const stats = GamificationStats(totalFocusMinutes: 600);
      expect(badgeById('focus_10h')!.isEarned(stats), isTrue);
      expect(badgeById('first_session')!.isEarned(stats), isFalse);
    });
  });
}
