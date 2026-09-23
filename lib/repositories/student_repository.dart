import '../models/student.dart';
import '../services/database_service.dart';

/// V1 supports a single local student profile — created once during
/// onboarding (Step 5) and updated from More/Settings (Step 13).
class StudentRepository {
  final _db = DatabaseService.instance;

  Future<void> save(Student student) async {
    final db = await _db.database;
    await db.insert('students', student.toMap());
  }

  Future<void> update(Student student) async {
    final db = await _db.database;
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  /// Returns null before onboarding has been completed.
  Future<Student?> getCurrent() async {
    final db = await _db.database;
    final rows = await db.query('students', limit: 1);
    if (rows.isEmpty) return null;
    return Student.fromMap(rows.first);
  }
}