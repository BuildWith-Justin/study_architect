import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/models/exam.dart';
import 'package:study_architect/models/study_session.dart';
import 'package:study_architect/models/subject.dart';
import 'package:study_architect/models/task.dart';
import 'package:study_architect/services/insights_engine.dart';

Subject _subject(String id, String name, {int target = 0}) => Subject(
      id: id,
      name: name,
      difficulty: SubjectDifficulty.medium,
      colorValue: 0xFF7C4DFF,
      weeklyTargetMinutes: target,
      createdAt: DateTime(2026, 1, 1),
    );

StudySession _done(
  String id,
  String subjectId,
  DateTime day,
  int minutes, {
  int hour = 17,
}) {
  final start = DateTime(day.year, day.month, day.day, hour);
  return StudySession(
    id: id,
    subjectId: subjectId,
    scheduledDate: DateTime(day.year, day.month, day.day),
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    actualDuration: minutes,
    status: SessionStatus.completed,
    complete: true,
  );
}

List<String> _ids(List<dynamic> insights) =>
    insights.map<String>((i) => i.id as String).toList();

void main() {
  // Wednesday 7 October 2026, 18:00.
  final now = DateTime(2026, 10, 7, 18);

  test('no data: only the first-session suggestion', () {
    final result = InsightsEngine.generate(
      sessions: const [],
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: const [],
      examProgress: const {},
      now: now,
    );
    expect(_ids(result), ['first-session']);
  });

  test('overdue task is reported', () {
    final result = InsightsEngine.generate(
      sessions: const [],
      subjects: [_subject('s1', 'Physics')],
      tasks: [
        Task(
          id: 't1',
          title: 'Lab report',
          subjectId: 's1',
          dueDate: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      exams: const [],
      examProgress: const {},
      now: now,
    );
    expect(_ids(result), contains('overdue'));
  });

  test('a close exam with unprepared topics ranks first', () {
    final result = InsightsEngine.generate(
      sessions: const [],
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: [
        Exam(
          id: 'e1',
          subjectId: 's1',
          title: 'Midterm',
          examDate: DateTime(2026, 10, 10, 9),
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
      examProgress: const {'e1': ExamProgress(prepared: 1, total: 4)},
      now: now,
    );
    expect(result.first.id, 'exam:e1');
  });

  test('streak at risk after 17:00 with a 3-day streak and no study today', () {
    final sessions = [
      _done('a', 's1', DateTime(2026, 10, 4), 20),
      _done('b', 's1', DateTime(2026, 10, 5), 20),
      _done('c', 's1', DateTime(2026, 10, 6), 20),
    ];
    final late = InsightsEngine.generate(
      sessions: sessions,
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: const [],
      examProgress: const {},
      now: now,
    );
    expect(_ids(late), contains('streak:2026-10-07'));

    final morning = InsightsEngine.generate(
      sessions: sessions,
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: const [],
      examProgress: const {},
      now: DateTime(2026, 10, 7, 10),
    );
    expect(_ids(morning), isNot(contains('streak:2026-10-07')));
  });

  test('a subject not studied for 7 days is flagged', () {
    final result = InsightsEngine.generate(
      sessions: [
        _done('a', 's1', DateTime(2026, 9, 28), 30),
        _done('b', 's1', DateTime(2026, 9, 30), 30),
      ],
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: const [],
      examProgress: const {},
      now: now,
    );
    expect(_ids(result), contains('neglected:s1'));
  });

  test('evening habit is detected after 8 recent sessions', () {
    final sessions = [
      for (var i = 1; i <= 10; i++)
        _done('s$i', 's1', DateTime(2026, 10, 7 - i * 2 + 14 - 14), 30,
            hour: 18),
    ];
    final result = InsightsEngine.generate(
      sessions: sessions,
      subjects: [_subject('s1', 'Physics')],
      tasks: const [],
      exams: const [],
      examProgress: const {},
      now: now,
    );
    expect(_ids(result), contains('pattern-time'));
  });
}
