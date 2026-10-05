import 'package:flutter_test/flutter_test.dart';
import 'package:study_architect/models/exam.dart';
import 'package:study_architect/models/exam_topic.dart';

void main() {
  Exam makeExam(DateTime date) => Exam(
        id: 'e1',
        subjectId: 's1',
        title: 'Calculus II midterm',
        examDate: date,
        createdAt: DateTime(2026, 10, 1, 8, 0),
      );

  group('Exam.daysLeft', () {
    test('counts calendar days and ignores the time of day', () {
      final now = DateTime(2026, 10, 5, 23, 30);
      expect(makeExam(DateTime(2026, 10, 20, 8, 0)).daysLeft(now), 15);
    });

    test('is 0 on the exam day and negative afterwards', () {
      final now = DateTime(2026, 10, 20, 18, 0);
      expect(makeExam(DateTime(2026, 10, 20, 8, 0)).daysLeft(now), 0);
      expect(makeExam(DateTime(2026, 10, 19, 8, 0)).daysLeft(now), -1);
    });

    test('isPast only becomes true the day after the exam', () {
      final now = DateTime(2026, 10, 20, 18, 0);
      expect(makeExam(DateTime(2026, 10, 20, 8, 0)).isPast(now), isFalse);
      expect(makeExam(DateTime(2026, 10, 19, 8, 0)).isPast(now), isTrue);
    });
  });

  group('Exam map round trip', () {
    test('toMap then fromMap gives the same exam', () {
      final exam = makeExam(DateTime(2026, 10, 20, 9, 30)).copyWith(
        location: 'Room 4',
        notes: 'Bring a calculator',
      );
      final back = Exam.fromMap(exam.toMap());
      expect(back.id, exam.id);
      expect(back.subjectId, exam.subjectId);
      expect(back.title, exam.title);
      expect(back.examDate, exam.examDate);
      expect(back.location, 'Room 4');
      expect(back.notes, 'Bring a calculator');
      expect(back.createdAt, exam.createdAt);
    });

    test('toMap never writes updatedAt (the database triggers do)', () {
      final map = makeExam(DateTime(2026, 10, 20)).toMap();
      expect(map.containsKey('updatedAt'), isFalse);
    });
  });

  group('ExamProgress', () {
    test('2 of 4 topics is 50 percent', () {
      const progress = ExamProgress(prepared: 2, total: 4);
      expect(progress.fraction, 0.5);
      expect(progress.percent, 50);
    });

    test('no topics gives 0 percent without dividing by zero', () {
      const progress = ExamProgress.empty();
      expect(progress.fraction, 0);
      expect(progress.percent, 0);
    });
  });

  group('ExamTopic', () {
    test('stores prepared as 0 or 1 and reads it back', () {
      const link = ExamTopic(
        id: 'l1',
        examId: 'e1',
        topicId: 't1',
        prepared: true,
      );
      expect(link.toMap()['prepared'], 1);
      expect(ExamTopic.fromMap(link.toMap()).prepared, isTrue);
      expect(link.copyWith(prepared: false).toMap()['prepared'], 0);
    });
  });
}
