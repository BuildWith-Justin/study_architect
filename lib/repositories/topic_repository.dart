import '../models/topic.dart';
import '../services/database_service.dart';

class TopicRepository {
  final _db = DatabaseService.instance;

  /// Always appends the topic at the end of its subject's roadmap,
  /// whatever sortOrder the caller passed in.
  Future<void> create(Topic topic) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sortOrder), -1) + 1 AS next '
      'FROM topics WHERE subjectId = ?',
      [topic.subjectId],
    );
    final next = (rows.first['next'] as int?) ?? 0;
    await db.insert('topics', topic.copyWith(sortOrder: next).toMap());
  }

  Future<void> update(Topic topic) async {
    final db = await _db.database;
    await db.update('topics', topic.toMap(),
        where: 'id = ?', whereArgs: [topic.id]);
  }

  /// Changes only the name, leaving position and completion untouched.
  Future<void> rename(String id, String name) async {
    final db = await _db.database;
    await db.update(
      'topics',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('topics', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setCompleted(String id, bool completed) async {
    final db = await _db.database;
    await db.update(
      'topics',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Topics of one subject in roadmap order (ties fall back to the
  /// order they were created in).
  Future<List<Topic>> getForSubject(String subjectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'topics',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'sortOrder ASC, rowid ASC',
    );
    return rows.map(Topic.fromMap).toList();
  }

  /// Saves a new roadmap order. [orderedIds] is the full list of topic
  /// ids of one subject, first topic first. Only rows whose position
  /// actually changed are written, so unchanged topics are not re-synced.
  Future<void> reorder(List<String> orderedIds) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'topics',
          {'sortOrder': i},
          where: 'id = ? AND sortOrder != ?',
          whereArgs: [orderedIds[i], i],
        );
      }
    });
  }
}
