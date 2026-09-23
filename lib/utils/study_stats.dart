import '../models/study_session.dart';
import 'date_utils.dart';

/// Sum of actualDuration (minutes) across completed sessions whose
/// scheduledDate falls on [date].
int completedMinutesForDate(List<StudySession> sessions, DateTime date) {
  return sessions
      .where((s) => s.complete && isSameDay(s.scheduledDate, date))
      .fold(0, (sum, s) => sum + (s.actualDuration ?? 0));
}

/// Sum of actualDuration across completed sessions within [sessions],
/// with no date filtering — pass in a week's worth of sessions to get
/// a weekly total.
int completedMinutesTotal(List<StudySession> sessions) {
  return sessions
      .where((s) => s.complete)
      .fold(0, (sum, s) => sum + (s.actualDuration ?? 0));
}

/// Current study streak, per the V1 business rule: a day counts only
/// if it has at least one completed session.
///
/// [completedDates] are yyyy-MM-dd strings from
/// SessionRepository.getCompletedDates(). Today not yet having a
/// completed session does not break the streak — it simply isn't
/// counted yet, since the day isn't over.
int currentStreak(Set<String> completedDates, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var cursor = startOfDay(now);
  var streak = 0;

  bool hasSessionOn(DateTime day) =>
      completedDates.contains(_dateKey(day));

  // If today already has a completed session, count it and step back
  // from yesterday. If not, today is skipped (not yet failed) and we
  // start checking from yesterday.
  if (hasSessionOn(cursor)) {
    streak++;
  }
  cursor = cursor.subtract(const Duration(days: 1));

  while (hasSessionOn(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Longest run of consecutive completed-session days on record, e.g.
/// for the "Longest: 18 days" line on the Progress screen.
int longestStreak(Set<String> completedDates) {
  if (completedDates.isEmpty) return 0;

  final sortedDates = completedDates.map((key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }).toList()
    ..sort();

  var longest = 1;
  var current = 1;
  for (var i = 1; i < sortedDates.length; i++) {
    final gap = sortedDates[i].difference(sortedDates[i - 1]).inDays;
    if (gap == 1) {
      current++;
      longest = current > longest ? current : longest;
    } else if (gap > 1) {
      current = 1;
    }
  }
  return longest;
}