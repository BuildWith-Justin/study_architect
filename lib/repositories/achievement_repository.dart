import '../models/achievement.dart';
import '../services/database_service.dart';

/// Reads and writes unlocked badges. A badge is never removed once
/// unlocked (only "Clear All Data" wipes the table).
class AchievementRepository {
  final _db = DatabaseService.instance;

  /// Unlocks a badge. Returns true only the first time, so the caller
  /// knows when to show a celebration.
  Future<bool> unlock(String id, {DateTime? at}) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'achievements',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      final badge = Achievement(id: id, unlockedAt: at ?? DateTime.now());
      await txn.insert('achievements', badge.toMap());
      return true;
    });
  }

  Future<bool> isUnlocked(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'achievements',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getUnlockedIds() async {
    final db = await _db.database;
    final rows = await db.query('achievements', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  /// Every unlocked badge, newest first.
  Future<List<Achievement>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('achievements', orderBy: 'unlockedAt DESC');
    return rows.map(Achievement.fromMap).toList();
  }

  Future<List<Achievement>> getRecent({int limit = 3}) async {
    final db = await _db.database;
    final rows = await db.query(
      'achievements',
      orderBy: 'unlockedAt DESC',
      limit: limit,
    );
    return rows.map(Achievement.fromMap).toList();
  }
}
