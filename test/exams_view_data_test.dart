import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_architect/models/exam.dart';
import 'package:study_architect/models/subject.dart';
import 'package:study_architect/models/topic.dart';
import 'package:study_architect/repositories/exam_repository.dart';
import 'package:study_architect/repositories/subject_repository.dart';
import 'package:study_architect/repositories/topic_repository.dart';
import 'package:study_architect/screens/exams/exams_view_data.dart';
import 'package:study_architect/services/database_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Own folder, so this file never shares a database with other tests.
    final dir = Directory(
      join(Directory.systemTemp.path, 'study_architect_exams_view_test'),
    );
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    await DatabaseService.instance.clearAllData();
    final db = await DatabaseService.instance.database;
    await db.delete('sync_tombstones');
  });

  test('empty database gives an empty exams view', () async {
    final data = await ExamsViewData.load();
    expect(data.isEmpty, isTrue);
    expect(data.totalCount, 0);
  });

  test('splits upcoming and past, sorts them, adds subject and progress',
      () async {
    final now = DateTime.now();
    await SubjectRepository().create(
      Subject(
        id: 's1',
        name: 'Calculus II',
        difficulty: SubjectDifficulty.medium,
        colorValue: 0xFF1AAE8F,
        weeklyTargetMinutes: 120,
        createdAt: now,
      ),
    );
    await TopicRepository()
        .create(const Topic(id: 't1', subjectId: 's1', name: 'Limits'));
    await TopicRepository()
        .create(const Topic(id: 't2', subjectId: 's1', name: 'Series'));

    Exam exam(String id, int daysFromNow) => Exam(
          id: id,
          subjectId: 's1',
          title: 'Exam $id',
          examDate: now.add(Duration(days: daysFromNow)),
          createdAt: now,
        );

    final repo = ExamRepository();
    await repo.create(exam('past', -3));
    await repo.create(exam('later', 20));
    await repo.create(exam('soon', 5), topicIds: ['t1', 't2']);

    final soonLinks = await repo.getTopicLinks('soon');
    await repo.setTopicPrepared(soonLinks.first.id, true);

    final data = await ExamsViewData.load();

    expect(data.upcoming.map((s) => s.exam.id).toList(), ['soon', 'later']);
    expect(data.past.map((s) => s.exam.id).toList(), ['past']);
    expect(data.totalCount, 3);
    expect(data.upcoming.first.subject?.name, 'Calculus II');
    expect(data.upcoming.first.progress.percent, 50);
    expect(data.upcoming.last.progress.total, 0);
  });
}
