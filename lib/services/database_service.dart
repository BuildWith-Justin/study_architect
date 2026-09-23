import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite Database instance and schema. Screens never
/// touch this directly — they go through the repositories in
/// lib/repositories/, which call DatabaseService.instance.database.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbName = 'study_architect.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createSchema,
      // sqflite does not enforce foreign keys by default — turn them on
      // so the ON DELETE CASCADE / SET NULL rules above actually run.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        school TEXT NOT NULL,
        program TEXT NOT NULL,
        level TEXT NOT NULL,
        dailyGoalMinutes INTEGER NOT NULL,
        weeklyGoalMinutes INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        weeklyTargetMinutes INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        subjectId TEXT NOT NULL,
        name TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id TEXT PRIMARY KEY,
        subjectId TEXT NOT NULL,
        topicId TEXT,
        scheduledDate TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        actualDuration INTEGER,
        status TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        rating INTEGER,
        complete INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE,
        FOREIGN KEY (topicId) REFERENCES topics (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subjectId TEXT NOT NULL,
        topicId TEXT,
        dueDate TEXT NOT NULL,
        type TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE,
        FOREIGN KEY (topicId) REFERENCES topics (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        notificationsEnabled INTEGER NOT NULL DEFAULT 1,
        themeMode TEXT NOT NULL DEFAULT 'system'
      )
    ''');
  }

  /// Wipes every table but keeps the schema — used by the
  /// "Clear All Data" danger-zone action in Step 14.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('study_sessions');
    await db.delete('topics');
    await db.delete('subjects');
    await db.delete('students');
    await db.delete('settings');
  }

  /// Full replace restore from a parsed backup JSON (see
  /// BackupService for the schema). Deletes everything currently
  /// stored, then inserts every row from the backup directly —
  /// bypassing repository-level validation (e.g. StudySession's
  /// end-after-start check) since this is trusted historical data
  /// that was valid when it was first saved.
  Future<void> restoreFromBackup({
    Map<String, dynamic>? student,
    Map<String, dynamic>? settings,
    required List<Map<String, dynamic>> subjects,
    required List<Map<String, dynamic>> topics,
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('study_sessions');
      await txn.delete('topics');
      await txn.delete('subjects');
      await txn.delete('students');
      await txn.delete('settings');

      if (student != null) {
        await txn.insert('students', student);
      }
      if (settings != null) {
        await txn.insert('settings', {...settings, 'id': 0});
      }
      for (final row in subjects) {
        await txn.insert('subjects', row);
      }
      for (final row in topics) {
        await txn.insert('topics', row);
      }
      for (final row in sessions) {
        await txn.insert('study_sessions', row);
      }
      for (final row in tasks) {
        await txn.insert('tasks', row);
      }
    });
  }
}