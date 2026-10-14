import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/data_refresh_bus.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';

/// Remembers which account owns the data stored on this phone.
///
/// When a different account signs in, the old account's data is removed
/// from the phone (it stays safe in that account's own cloud) so two
/// accounts never get mixed together.
class LocalOwnerService {
  LocalOwnerService._();
  static final LocalOwnerService instance = LocalOwnerService._();

  static const _ownerKey = 'owner';

  /// Call once per sign-in, before the app screens are shown.
  Future<void> ensureOwner(String uid) async {
    final sync = SyncService.instance;
    // Nothing may upload or download while ownership is being decided.
    await sync.pauseAndWaitIdle();
    try {
      final db = await DatabaseService.instance.database;
      final owner = await _getOwner(db);

      if (owner == uid) return;

      var foreign = false;
      if (owner != null) {
        foreign = true;
      } else {
        // Older installs never stored an owner. Infer it: data on the
        // phone plus sync bookmarks of another account means the data
        // belongs to that other account.
        foreign =
            await _hasLocalData(db) && await _hasForeignSyncState(db, uid);
      }

      if (foreign) {
        debugPrint('LocalOwner: different account detected, clearing phone');
        await DatabaseService.instance.clearAllData();
        await db.delete(
          'sync_meta',
          where: 'key LIKE ? OR key LIKE ?',
          whereArgs: ['push:%', 'pull:%'],
        );
        await db.delete('sync_tombstones');
        await _resetReminders();
        DataRefreshBus.instance.notify(RefreshScope.all);
      }

      await _setOwner(db, uid);
    } finally {
      sync.resume();
    }
  }

  Future<String?> _getOwner(Database db) async {
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [_ownerKey],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setOwner(Database db, String uid) {
    return db.insert(
      'sync_meta',
      {'key': _ownerKey, 'value': uid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _hasLocalData(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM students');
    final count = Sqflite.firstIntValue(rows) ?? 0;
    return count > 0;
  }

  /// Sync bookmark keys look like `pull:UID:TABLE` or `push:UID:TABLE`.
  Future<bool> _hasForeignSyncState(Database db, String uid) async {
    final rows = await db.query(
      'sync_meta',
      columns: ['key'],
      where: 'key LIKE ? OR key LIKE ?',
      whereArgs: ['push:%', 'pull:%'],
    );
    for (final row in rows) {
      final parts = (row['key'] as String).split(':');
      if (parts.length >= 3 && parts[1] != uid) return true;
    }
    return false;
  }

  Future<void> _resetReminders() async {
    try {
      await NotificationService.instance.cancelAllReminders();
      await NotificationService.instance.applyAll();
    } catch (e) {
      debugPrint('LocalOwner: reminder reset skipped: $e');
    }
  }
}
