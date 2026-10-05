import '../../models/exam.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/exam_repository.dart';
import '../../repositories/session_repository.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart';

/// Everything the Calendar screen needs for one visible month.
/// Dates used as map keys are local midnights (startOfDay).
class CalendarViewData {
  /// First day of the month this data was loaded for.
  final DateTime focusedMonth;

  /// Minutes actually studied (completed sessions) per day.
  final Map<DateTime, int> studiedMinutesByDay;
  final Map<DateTime, List<StudySession>> sessionsByDay;
  final Map<DateTime, List<Exam>> examsByDay;
  final Map<String, Subject> subjectsById;
  final Map<String, Topic> topicsById;

  /// Totals for the focused month only.
  final int monthMinutes;
  final int monthStudyDays;

  const CalendarViewData({
    required this.focusedMonth,
    required this.studiedMinutesByDay,
    required this.sessionsByDay,
    required this.examsByDay,
    required this.subjectsById,
    required this.topicsById,
    required this.monthMinutes,
    required this.monthStudyDays,
  });

  /// Loads the month plus 7 days on each side, so the greyed-out days
  /// of the neighbouring months in the grid also get their dots.
  static Future<CalendarViewData> load(DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final windowStart = DateTime(first.year, first.month, 1 - 7);
    final windowEnd = DateTime(first.year, first.month + 1, 1 + 7);

    final sessions =
        await SessionRepository().getForRange(windowStart, windowEnd);
    final allExams = await ExamRepository().getAll();

    final db = await DatabaseService.instance.database;
    final subjectRows = await db.query('subjects');
    final topicRows = await db.query('topics');

    final subjectsById = <String, Subject>{
      for (final row in subjectRows)
        (row['id'] as String): Subject.fromMap(row),
    };
    final topicsById = <String, Topic>{
      for (final row in topicRows) (row['id'] as String): Topic.fromMap(row),
    };

    final studied = <DateTime, int>{};
    final sessionsByDay = <DateTime, List<StudySession>>{};
    for (final s in sessions) {
      final key = startOfDay(s.scheduledDate);
      sessionsByDay.putIfAbsent(key, () => []).add(s);
      // Same rule as the rest of the app: only completed sessions count.
      if (s.complete) {
        studied[key] = (studied[key] ?? 0) + (s.actualDuration ?? 0);
      }
    }

    final examsByDay = <DateTime, List<Exam>>{};
    final sortedExams = [...allExams]
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
    for (final e in sortedExams) {
      final key = startOfDay(e.examDate);
      if (key.isBefore(startOfDay(windowStart)) ||
          key.isAfter(startOfDay(windowEnd))) {
        continue;
      }
      examsByDay.putIfAbsent(key, () => []).add(e);
    }

    var monthMinutes = 0;
    var monthStudyDays = 0;
    studied.forEach((day, minutes) {
      if (day.year == first.year && day.month == first.month && minutes > 0) {
        monthMinutes += minutes;
        monthStudyDays++;
      }
    });

    return CalendarViewData(
      focusedMonth: first,
      studiedMinutesByDay: studied,
      sessionsByDay: sessionsByDay,
      examsByDay: examsByDay,
      subjectsById: subjectsById,
      topicsById: topicsById,
      monthMinutes: monthMinutes,
      monthStudyDays: monthStudyDays,
    );
  }
}
