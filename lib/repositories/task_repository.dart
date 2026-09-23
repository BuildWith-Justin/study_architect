import '../models/task.dart';
import '../services/database_service.dart';

class TaskRepository {
  final _db = DatabaseService.instance;

  Future<void> create(Task task) async {
    final db = await _db.database;
    await db.insert('tasks', task.toMap());
  }

  Future<void> update(Task task) async {
    final db = await _db.database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setCompleted(String id, bool completed) async {
    final db = await _db.database;
    await db.update(
      'tasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> getForDate(DateTime date) async {
    final db = await _db.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final rows = await db.query(
      'tasks',
      where: 'dueDate >= ? AND dueDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'dueDate ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('tasks', orderBy: 'dueDate ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getForSubject(String subjectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'dueDate ASC',
    );
    return rows.map(Task.fromMap).toList();
  }
}