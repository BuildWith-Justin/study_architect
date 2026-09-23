import 'package:sqflite/sqflite.dart';
import '../models/subject.dart';
import '../services/database_service.dart';

class SubjectRepository {
  final _db = DatabaseService.instance;

  Future<void> create(Subject subject) async {
    final db = await _db.database;
    await db.insert('subjects', subject.toMap());
  }

  Future<void> update(Subject subject) async {
    final db = await _db.database;
    await db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  /// Deletes the subject. Related topics/sessions/tasks cascade via
  /// the foreign keys in DatabaseService — callers should warn the
  /// user before calling this (business rule from the V1 spec).
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<Subject?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  Future<List<Subject>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('subjects', orderBy: 'createdAt ASC');
    return rows.map(Subject.fromMap).toList();
  }

  /// Counts topics + sessions + tasks tied to a subject, so the UI can
  /// show "this will also delete N related items" before confirming.
  Future<int> countRelatedRecords(String subjectId) async {
    final db = await _db.database;
    final topics = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM topics WHERE subjectId = ?',
      [subjectId],
    ));
    final sessions = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM study_sessions WHERE subjectId = ?',
      [subjectId],
    ));
    final tasks = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE subjectId = ?',
      [subjectId],
    ));
    return (topics ?? 0) + (sessions ?? 0) + (tasks ?? 0);
  }
}