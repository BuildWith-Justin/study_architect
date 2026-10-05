import 'package:sqflite/sqflite.dart';

/// Tables that are mirrored to Supabase (the original set, schema v2).
const syncedTables = [
  'students',
  'settings',
  'subjects',
  'topics',
  'study_sessions',
  'tasks',
];

/// V2 Step 11: exam tables, added to the sync at schema v5. They have
/// their own function below because their tables are created later than
/// the original ones.
const examSyncedTables = [
  'exams',
  'exam_topics',
];

// SQLite expression for "now" in the same format Dart's toIso8601String()
// produces (UTC, millisecond precision) so strings compare correctly.
const _now = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";

Future<void> _ensureMetaTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_tombstones (
      tableName TEXT NOT NULL,
      rowId TEXT NOT NULL,
      deletedAt TEXT NOT NULL,
      PRIMARY KEY (tableName, rowId)
    )
  ''');
}

/// Stamps existing rows and creates the three bookkeeping triggers for
/// one table. Safe to run twice (IF NOT EXISTS).
Future<void> _stampAndCreateTriggers(Database db, String t) async {
  // Existing rows get a timestamp so they upload on the first sync.
  await db.execute('UPDATE $t SET updatedAt = $_now WHERE updatedAt IS NULL');

  // New row: stamp it, and cancel any pending delete for the same id
  // (happens when a backup restore re-inserts a row).
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_${t}_ai AFTER INSERT ON $t
    BEGIN
      DELETE FROM sync_tombstones
        WHERE tableName = '$t' AND rowId = CAST(NEW.id AS TEXT);
      UPDATE $t SET updatedAt = $_now
        WHERE rowid = NEW.rowid AND updatedAt IS NULL;
    END
  ''');

  // Edited row: repositories never set updatedAt, so it is unchanged
  // here and we stamp it. Rows written by the sync itself carry a
  // different updatedAt, so they are left alone.
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_${t}_au AFTER UPDATE ON $t
    WHEN NEW.updatedAt IS OLD.updatedAt
    BEGIN
      UPDATE $t SET updatedAt = $_now WHERE rowid = NEW.rowid;
    END
  ''');

  // Deleted row: remember it so the delete can be sent to the cloud.
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_${t}_ad AFTER DELETE ON $t
    BEGIN
      INSERT OR REPLACE INTO sync_tombstones (tableName, rowId, deletedAt)
      VALUES ('$t', CAST(OLD.id AS TEXT), $_now);
    END
  ''');
}

/// Adds sync bookkeeping to the local database (schema v2).
/// - updatedAt column on every synced table
/// - triggers that stamp updatedAt on insert/update
/// - triggers that record deletes in sync_tombstones
Future<void> applySyncSchema(Database db) async {
  await _ensureMetaTables(db);

  for (final t in syncedTables) {
    await db.execute('ALTER TABLE $t ADD COLUMN updatedAt TEXT');
    await _stampAndCreateTriggers(db, t);
  }
}

/// Same bookkeeping for the exam tables (schema v5). Can be run more than
/// once: it only adds what is missing.
Future<void> applyExamSyncSchema(Database db) async {
  await _ensureMetaTables(db);

  for (final t in examSyncedTables) {
    final info = await db.rawQuery('PRAGMA table_info($t)');
    final hasUpdatedAt = info.any((c) => c['name'] == 'updatedAt');
    if (!hasUpdatedAt) {
      await db.execute('ALTER TABLE $t ADD COLUMN updatedAt TEXT');
    }
    await _stampAndCreateTriggers(db, t);
  }
}
