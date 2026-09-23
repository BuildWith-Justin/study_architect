import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../utils/date_utils.dart';

/// A week's worth of sessions plus lookup maps, so the Timetable
/// screen can switch days without re-hitting the database each time.
class TimetableWeekData {
  final List<StudySession> sessions;
  final Map<String, Subject> subjectsById;
  final Map<String, Topic> topicsById;

  const TimetableWeekData({
    required this.sessions,
    required this.subjectsById,
    required this.topicsById,
  });

  List<StudySession> forDay(DateTime day) {
    final list = sessions.where((s) => isSameDay(s.scheduledDate, day)).toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  static Future<TimetableWeekData> load(DateTime anyDayInWeek) async {
    final sessionRepo = SessionRepository();
    final subjectRepo = SubjectRepository();
    final topicRepo = TopicRepository();

    final start = startOfWeek(anyDayInWeek);
    final end = endOfWeek(anyDayInWeek);

    final sessions = await sessionRepo.getForRange(start, end);
    final subjects = await subjectRepo.getAll();
    final subjectsById = {for (final s in subjects) s.id: s};

    final topicsById = <String, Topic>{};
    for (final subject in subjects) {
      final topics = await topicRepo.getForSubject(subject.id);
      for (final topic in topics) {
        topicsById[topic.id] = topic;
      }
    }

    return TimetableWeekData(
      sessions: sessions,
      subjectsById: subjectsById,
      topicsById: topicsById,
    );
  }
}