import '../models/study_session.dart';
import '../utils/date_utils.dart';
import 'xp_rules.dart';

/// yyyy-MM-dd, the same key format used by SessionRepository.
String dayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime _parseDayKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime _previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Days on which the completed sessions add up to at least
/// [minMinutes] - the days that count for the streak.
Set<String> qualifyingDays(
  Iterable<StudySession> sessions, {
  int minMinutes = XpRules.minStudyDayMinutes,
}) {
  final minutesByDay = <String, int>{};
  for (final s in sessions) {
    if (!s.complete) continue;
    final key = dayKey(s.scheduledDate);
    minutesByDay[key] = (minutesByDay[key] ?? 0) + (s.actualDuration ?? 0);
  }
  return {
    for (final e in minutesByDay.entries)
      if (e.value >= minMinutes) e.key,
  };
}

class StreakResult {
  /// Number of studied days in the streak (forgiven days are not counted).
  final int length;

  /// Missed days that the weekly freeze forgave (yyyy-MM-dd).
  final Set<String> bridgedDays;

  /// True when this week's free missed day has already been used.
  final bool freezeUsedThisWeek;

  const StreakResult({
    required this.length,
    this.bridgedDays = const <String>{},
    this.freezeUsedThisWeek = false,
  });

  static const StreakResult empty = StreakResult(length: 0);
}

/// Streak ending on [asOf].
/// - [asOf] counts when it is a qualifying day; if it is not, it is
///   skipped (the day is not over yet) and counting starts the day before.
/// - One missed day per week is forgiven (the freeze), but two missed
///   days in a row always break the streak.
StreakResult streakAsOf(Set<String> days, DateTime asOf) {
  if (days.isEmpty) return StreakResult.empty;

  final earliest =
      days.map(_parseDayKey).reduce((a, b) => a.isBefore(b) ? a : b);

  var cursor = startOfDay(asOf);
  var length = 0;
  if (days.contains(dayKey(cursor))) length++;
  cursor = _previousDay(cursor);

  final confirmed = <String>{};
  final pending = <String>[];
  final usedWeeks = <String>{};
  var lastWasBridge = false;

  while (!cursor.isBefore(earliest)) {
    final key = dayKey(cursor);
    if (days.contains(key)) {
      length++;
      // A forgiven day only counts once a studied day lies before it.
      confirmed.addAll(pending);
      pending.clear();
      lastWasBridge = false;
    } else {
      final week = dayKey(startOfWeek(cursor));
      if (lastWasBridge || usedWeeks.contains(week)) break;
      usedWeeks.add(week);
      pending.add(key);
      lastWasBridge = true;
    }
    cursor = _previousDay(cursor);
  }

  final thisWeek = dayKey(startOfWeek(asOf));
  final freezeUsed =
      confirmed.any((k) => dayKey(startOfWeek(_parseDayKey(k))) == thisWeek);

  return StreakResult(
    length: length,
    bridgedDays: confirmed,
    freezeUsedThisWeek: freezeUsed,
  );
}

/// Longest streak ever reached.
int bestStreak(Set<String> days) {
  var best = 0;
  for (final key in days) {
    final len = streakAsOf(days, _parseDayKey(key)).length;
    if (len > best) best = len;
  }
  return best;
}
