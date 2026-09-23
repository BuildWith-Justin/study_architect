import '../models/topic.dart';
import '../services/database_service.dart';

class TopicRepository {
  final _db = DatabaseService.instance;

  Future<void> create(Topic topic) async {
    final db = await _db.database;
    await db.insert('topics', topic.toMap());
  }

  Future<void> update(Topic topic) async {
    final db = await _db.database;
    await db.update('topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
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

  Future<List<Topic>> getForSubject(String subjectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'topics',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
    );
    return rows.map(Topic.fromMap).toList();
  }
}