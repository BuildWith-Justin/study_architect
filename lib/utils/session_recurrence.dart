import 'package:uuid/uuid.dart';
import '../models/study_session.dart';

/// Hard cap so a weekly repeat can never create an unbounded number of rows.
const int kMaxWeeklyOccurrences = 52;

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// How many weekly occurrences fall between [first] and [until] (inclusive).
/// Always at least 1 and never more than [maxOccurrences].
int countWeeklyOccurrences(
  DateTime first,
  DateTime until, {
  int maxOccurrences = kMaxWeeklyOccurrences,
}) {
  final start = _dayOnly(first);
  final end = _dayOnly(until);
  var count = 0;
  for (var week = 0; week < maxOccurrences; week++) {
    final date = DateTime(start.year, start.month, start.day + 7 * week);
    if (week > 0 && date.isAfter(end)) break;
    count++;
  }
  return count;
}

/// Expands one session into a weekly series: the same weekday and the
/// same start/end time, every 7 days, up to and including [until].
/// The first element keeps [first]'s id; the others get new ids.
/// All of them share one seriesId.
List<StudySession> buildWeeklySeries({
  required StudySession first,
  required DateTime until,
  int maxOccurrences = kMaxWeeklyOccurrences,
}) {
  final seriesId = first.seriesId ?? const Uuid().v4();
  final start = _dayOnly(first.scheduledDate);
  final end = _dayOnly(until);
  final result = <StudySession>[];

  for (var week = 0; week < maxOccurrences; week++) {
    final date = DateTime(start.year, start.month, start.day + 7 * week);
    if (week > 0 && date.isAfter(end)) break;

    result.add(
      StudySession(
        id: week == 0 ? first.id : const Uuid().v4(),
        subjectId: first.subjectId,
        topicId: first.topicId,
        scheduledDate: date,
        startTime: DateTime(
          date.year,
          date.month,
          date.day,
          first.startTime.hour,
          first.startTime.minute,
        ),
        endTime: DateTime(
          date.year,
          date.month,
          date.day,
          first.endTime.hour,
          first.endTime.minute,
        ),
        status: SessionStatus.planned,
        notes: first.notes,
        recurrence: SessionRecurrence.weekly,
        recurrenceUntil: end,
        seriesId: seriesId,
      ),
    );
  }
  return result;
}
