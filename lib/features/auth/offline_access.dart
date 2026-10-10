import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/database_service.dart';

/// Lets the app open without a Supabase session when the person is simply
/// offline (for example an expired login that cannot refresh without
/// internet). Rule: no session + a profile saved on this phone + the person
/// did not tap Sign out = keep using the app locally.
/// A new user, or someone who cleared the app data, has no saved profile,
/// so they still have to sign in or sign up first.
class OfflineAccess {
  OfflineAccess._();

  static const _signedOutKey = 'auth:signedOut';

  /// Called when the person taps Sign out.
  static Future<void> markSignedOut() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.insert(
        'sync_meta',
        {'key': _signedOutKey, 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('OfflineAccess.markSignedOut failed: $e');
    }
  }

  /// Called whenever a real session exists (signed in again).
  static Future<void> clearSignedOut() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(
        'sync_meta',
        where: 'key = ?',
        whereArgs: [_signedOutKey],
      );
    } catch (e) {
      debugPrint('OfflineAccess.clearSignedOut failed: $e');
    }
  }

  /// True when the app may open without a session.
  static Future<bool> canUseWithoutSession() async {
    try {
      final db = await DatabaseService.instance.database;
      final students =
          await db.query('students', columns: ['id'], limit: 1);
      if (students.isEmpty) return false;

      final flag = await db.query(
        'sync_meta',
        where: 'key = ?',
        whereArgs: [_signedOutKey],
        limit: 1,
      );
      return flag.isEmpty;
    } catch (e) {
      debugPrint('OfflineAccess.canUseWithoutSession failed: $e');
      return false;
    }
  }
}
