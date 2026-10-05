import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/exam.dart';
import '../models/exam_topic.dart';
import '../services/database_service.dart';

/// All reads and writes for exams and their topic checklist.
/// Like the other repositories, it does not notify DataRefreshBus —
/// the screens that change data call
/// DataRefreshBus.instance.notify(RefreshScope.exams) afterwards.
class ExamRepository {
  final _db = DatabaseService.instance;
  static const _uuid = Uuid();

  /// Creates the exam and, in the same transaction, its topic checklist.
  Future<void> create(Exam exam, {List<String> topicIds = const []}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('exams', exam.toMap());
      for (final topicId in topicIds.toSet()) {
        await txn.insert(
          'exam_topics',
          ExamTopic(id: _uuid.v4(), examId: exam.id, topicId: topicId).toMap(),
        );
      }
    });
  }

  /// Updates the exam. When [topicIds] is given, the checklist is made to
  /// match it: removed topics are deleted, new ones are added, and topics
  /// that stay keep their "prepared" state.
  Future<void> update(Exam exam, {List<String>? topicIds}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'exams',
        exam.toMap(),
        where: 'id = ?',
        whereArgs: [exam.id],
      );
      if (topicIds != null) {
        await _syncTopicLinks(txn, exam.id, topicIds);
      }
    });
  }

  Future<void> _syncTopicLinks(
    DatabaseExecutor txn,
    String examId,
    List<String> topicIds,
  ) async {
    final wanted = topicIds.toSet();
    final rows = await txn.query(
      'exam_topics',
      where: 'examId = ?',
      whereArgs: [examId],
    );
    final existing = <String, String>{
      for (final r in rows) r['topicId'] as String: r['id'] as String,
    };

    for (final entry in existing.entries) {
      if (!wanted.contains(entry.key)) {
        await txn.delete(
          'exam_topics',
          where: 'id = ?',
          whereArgs: [entry.value],
        );
      }
    }
    for (final topicId in wanted) {
      if (!existing.containsKey(topicId)) {
        await txn.insert(
          'exam_topics',
          ExamTopic(id: _uuid.v4(), examId: examId, topicId: topicId).toMap(),
        );
      }
    }
  }

  /// Deletes the exam. Its checklist rows cascade.
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  Future<Exam?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('exams', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Exam.fromMap(rows.first);
  }

  /// Every exam, nearest date first (past exams come first).
  Future<List<Exam>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('exams', orderBy: 'examDate ASC');
    return rows.map(Exam.fromMap).toList();
  }

  /// Exams from today onwards, nearest first. Pass [limit] to cap the list
  /// (the Home card asks for the nearest few).
  Future<List<Exam>> getUpcoming({int? limit, DateTime? now}) async {
    final db = await _db.database;
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final rows = await db.query(
      'exams',
      where: 'examDate >= ?',
      whereArgs: [startOfToday.toIso8601String()],
      orderBy: 'examDate ASC',
      limit: limit,
    );
    return rows.map(Exam.fromMap).toList();
  }

  Future<List<Exam>> getForSubject(String subjectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'exams',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'examDate ASC',
    );
    return rows.map(Exam.fromMap).toList();
  }

  /// The checklist of one exam, in the subject's roadmap order.
  Future<List<ExamTopic>> getTopicLinks(String examId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT et.* FROM exam_topics et '
      'JOIN topics t ON t.id = et.topicId '
      'WHERE et.examId = ? '
      'ORDER BY t.sortOrder ASC, t.rowid ASC',
      [examId],
    );
    return rows.map(ExamTopic.fromMap).toList();
  }

  /// Every checklist row of every exam (used by backups).
  Future<List<ExamTopic>> getAllTopicLinks() async {
    final db = await _db.database;
    final rows = await db.query('exam_topics', orderBy: 'rowid ASC');
    return rows.map(ExamTopic.fromMap).toList();
  }

  /// Ticks or unticks one topic of an exam's checklist.
  Future<void> setTopicPrepared(String examTopicId, bool prepared) async {
    final db = await _db.database;
    await db.update(
      'exam_topics',
      {'prepared': prepared ? 1 : 0},
      where: 'id = ?',
      whereArgs: [examTopicId],
    );
  }

  Future<ExamProgress> getProgress(String examId) async {
    final all = await getProgressForAll();
    return all[examId] ?? const ExamProgress.empty();
  }

  /// Progress of every exam in one query, keyed by exam id. Exams without
  /// topics are simply absent from the map.
  Future<Map<String, ExamProgress>> getProgressForAll() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT examId, COUNT(*) AS total, '
      'COALESCE(SUM(prepared), 0) AS prepared '
      'FROM exam_topics GROUP BY examId',
    );
    return {
      for (final r in rows)
        r['examId'] as String: ExamProgress(
          prepared: (r['prepared'] as int?) ?? 0,
          total: (r['total'] as int?) ?? 0,
        ),
    };
  }
}
