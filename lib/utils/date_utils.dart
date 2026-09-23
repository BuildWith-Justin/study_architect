/// Small date helpers shared by Home, Timetable, and Progress —
/// keeps "start of day" / "start of week" logic in one place.
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Monday-start week, matching the spec's "Week • September 8–14" style.
DateTime startOfWeek(DateTime date) {
  final day = startOfDay(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime endOfWeek(DateTime date) => startOfWeek(date).add(const Duration(days: 7));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String formatTimeOfDay(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}