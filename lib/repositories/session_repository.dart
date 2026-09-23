import '../models/study_session.dart';
import '../services/database_service.dart';

class SessionRepository {
  final _db = DatabaseService.instance;

  /// Throws if the session's end time is not after its start time —
  /// enforces the V1 business rule at the persistence boundary.
  Future<void> create(StudySession session) async {
    if (!session.isTimeRangeValid) {
      throw ArgumentError('Session end time must be after start time.');
    }
    final db = await _db.database;
    await db.insert('study_sessions', session.toMap());
  }

  Future<void> update(StudySession session) async {
    if (!session.isTimeRangeValid) {
      throw ArgumentError('Session end time must be after start time.');
    }
    final db = await _db.database;
    await db.update(
      'study_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('study_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<StudySession?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('study_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudySession.fromMap(rows.first);
  }

  /// Sessions scheduled on one calendar day — powers Home's "today's
  /// schedule" and the streak calculation (Step 9).
  Future<List<StudySession>> getForDate(DateTime date) async {
    final db = await _db.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final rows = await db.query(
      'study_sessions',
      where: 'scheduledDate >= ? AND scheduledDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  /// Sessions within an inclusive date range — powers the Timetable
  /// week view and Progress screen (Step 8, Step 9).
  Future<List<StudySession>> getForRange(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.query(
      'study_sessions',
      where: 'scheduledDate >= ? AND scheduledDate <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  Future<List<StudySession>> getForSubject(String subjectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'study_sessions',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'scheduledDate DESC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  /// Distinct calendar dates (as yyyy-MM-dd strings) that have at
  /// least one completed session — the raw material for the streak
  /// calculation in utils/study_stats.dart.
  Future<Set<String>> getCompletedDates() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT substr(scheduledDate, 1, 10) as day
      FROM study_sessions
      WHERE complete = 1
    ''');
    return rows.map((r) => r['day'] as String).toSet();
  }

  /// Every session ever recorded — used by the Progress screen's
  /// "All time" view.
  Future<List<StudySession>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('study_sessions', orderBy: 'scheduledDate ASC');
    return rows.map(StudySession.fromMap).toList();
  }
}