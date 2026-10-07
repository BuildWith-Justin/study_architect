import 'package:sqflite/sqflite.dart';

import '../models/xp_entry.dart';
import '../services/database_service.dart';

/// Reads and writes the XP ledger. Like the other repositories it does
/// not notify the UI: the gamification engine does that after it awards.
class XpRepository {
  final _db = DatabaseService.instance;

  void _validate(XpEntry entry) {
    if (entry.amount <= 0) {
      throw ArgumentError('XP amount must be positive.');
    }
  }

  /// Adds an award. If this source already has one, nothing happens.
  /// Returns true only when a new row was written.
  Future<bool> award(XpEntry entry) async {
    _validate(entry);
    final db = await _db.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'xp_log',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.id],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      await txn.insert('xp_log', entry.toMap());
      return true;
    });
  }

  /// Adds the award, or refreshes it when the same source is already
  /// there with a different amount or reason (for example a session
  /// edited after completion). Returns true if anything changed.
  Future<bool> upsert(XpEntry entry) async {
    _validate(entry);
    final db = await _db.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'xp_log',
        where: 'id = ?',
        whereArgs: [entry.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert('xp_log', entry.toMap());
        return true;
      }
      final current = XpEntry.fromMap(rows.first);
      final sameDay = current.earnedAt.year == entry.earnedAt.year &&
          current.earnedAt.month == entry.earnedAt.month &&
          current.earnedAt.day == entry.earnedAt.day;
      if (current.amount == entry.amount &&
          current.reason == entry.reason &&
          sameDay) {
        return false;
      }
      await txn.update(
        'xp_log',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      return true;
    });
  }

  /// Removes the award of one source (used when a session or task is
  /// deleted). Returns how many rows were removed.
  Future<int> removeBySource(XpSource type, String sourceId) async {
    final db = await _db.database;
    return db.delete(
      'xp_log',
      where: 'sourceType = ? AND sourceId = ?',
      whereArgs: [type.name, sourceId],
    );
  }

  Future<bool> hasEntry(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'xp_log',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Source ids that already have an award of this type - lets the
  /// engine find which old sessions or tasks still need XP.
  Future<Set<String>> getSourceIds(XpSource type) async {
    final db = await _db.database;
    final rows = await db.query(
      'xp_log',
      columns: ['sourceId'],
      where: 'sourceType = ?',
      whereArgs: [type.name],
    );
    return rows.map((r) => r['sourceId'] as String).toSet();
  }

  Future<int> getTotalXp() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) FROM xp_log',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// XP earned on one calendar day (device local time).
  Future<int> getXpForDay(DateTime day) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) FROM xp_log '
      'WHERE earnedAt >= ? AND earnedAt < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// XP earned on one calendar day by one kind of source. Pass
  /// [excludeSourceId] to leave one source out (used to apply the daily
  /// cap to a session without counting its own previous award).
  Future<int> getXpForDayBySource(
    DateTime day,
    XpSource type, {
    String? excludeSourceId,
  }) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final args = <Object?>[
      type.name,
      start.toIso8601String(),
      end.toIso8601String(),
    ];
    var sql = 'SELECT COALESCE(SUM(amount), 0) FROM xp_log '
        'WHERE sourceType = ? AND earnedAt >= ? AND earnedAt < ?';
    if (excludeSourceId != null) {
      sql += ' AND sourceId != ?';
      args.add(excludeSourceId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Every award, newest first.
  Future<List<XpEntry>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('xp_log', orderBy: 'earnedAt DESC');
    return rows.map(XpEntry.fromMap).toList();
  }
}
