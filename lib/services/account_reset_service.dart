import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

/// Thrown when the wipe could not be completed. The message is meant to be
/// shown to the person. When this is thrown, nothing was removed from the
/// device.
class AccountResetException implements Exception {
  final String message;
  const AccountResetException(this.message);

  @override
  String toString() => message;
}

class _CloudRowsRemain implements Exception {
  final String table;
  const _CloudRowsRemain(this.table);
}

/// "Clear all data": removes the person's data from the cloud (when signed
/// in) AND from this device, but keeps the sign-in itself. The app then
/// restarts at profile setup.
class AccountResetService {
  AccountResetService._();
  static final AccountResetService instance = AccountResetService._();

  // Children first, so nothing is deleted before the rows that point to it.
  static const _cloudTables = [
    'xp_log',
    'achievements',
    'exam_topics',
    'exams',
    'tasks',
    'study_sessions',
    'topics',
    'subjects',
    'settings',
    'students',
  ];

  bool get _signedIn =>
      AuthService.isAvailable &&
      Supabase.instance.client.auth.currentUser != null;

  Future<void> wipeEverything() async {
    final sync = SyncService.instance;
    // Stop the background sync so it cannot re-upload or re-download rows
    // while the wipe is running.
    await sync.pauseAndWaitIdle();
    try {
      if (_signedIn) {
        await _wipeCloud();
      }
      await DatabaseService.instance.clearAllData();
      await _clearSyncState(everything: true);
    } finally {
      sync.resume();
    }
  }

  Future<void> _wipeCloud() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    final avatarPath = await _readLocalAvatarPath();

    try {
      for (final table in _cloudTables) {
        await client
            .from(table)
            .delete()
            .eq('user_id', uid)
            .timeout(const Duration(seconds: 20));
      }

      // Make sure the cloud really is empty (a missing delete permission
      // would otherwise fail silently).
      for (final table in _cloudTables) {
        final left = await client
            .from(table)
            .select('id')
            .eq('user_id', uid)
            .limit(1)
            .timeout(const Duration(seconds: 20));
        if (left.isNotEmpty) throw _CloudRowsRemain(table);
      }
    } catch (e) {
      debugPrint('AccountReset: cloud wipe failed: $e');
      // Part of the cloud may already be gone. Forget the upload bookmarks
      // so the next sync re-uploads everything that is still on the phone.
      await _clearSyncState(everything: false);
      if (e is _CloudRowsRemain) {
        throw const AccountResetException(
          'your account did not allow the deletion. '
          'Nothing was deleted from this device.',
        );
      }
      throw const AccountResetException(
        'your account could not be reached. Check your connection and try '
        'again. Nothing was deleted from this device.',
      );
    }

    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        await client.storage.from('avatars').remove([avatarPath]);
      } catch (e) {
        debugPrint('AccountReset: photo removal skipped: $e');
      }
    }
  }

  Future<String?> _readLocalAvatarPath() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery('SELECT avatarPath FROM students LIMIT 1');
      if (rows.isEmpty) return null;
      return rows.first['avatarPath'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// everything = true: forget all sync bookmarks and pending deletions.
  /// everything = false: only forget the upload bookmarks.
  Future<void> _clearSyncState({required bool everything}) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(
        'sync_meta',
        where: 'key LIKE ?',
        whereArgs: ['push:%'],
      );
      if (everything) {
        await db.delete(
          'sync_meta',
          where: 'key LIKE ?',
          whereArgs: ['pull:%'],
        );
        await db.delete('sync_tombstones');
      }
    } catch (e) {
      debugPrint('AccountReset: sync state cleanup skipped: $e');
    }
  }
}
