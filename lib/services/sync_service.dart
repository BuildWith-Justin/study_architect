import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/data_refresh_bus.dart';
import 'database_service.dart';

class _SyncTable {
  final String name;

  /// settings uses an INTEGER id locally; the cloud stores ids as text.
  final bool intId;
  const _SyncTable(this.name, {this.intId = false});
}

// Parents first, so children never arrive before the row they reference.
const _tables = [
  _SyncTable('students'),
  _SyncTable('settings', intId: true),
  _SyncTable('subjects'),
  _SyncTable('topics'),
  _SyncTable('study_sessions'),
  _SyncTable('tasks'),
];

/// UTC ISO-8601 with millisecond precision — the same shape SQLite writes,
/// so plain string comparison orders timestamps correctly.
String _iso(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
      d.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _pageSize = 500;

  SupabaseClient get _client => Supabase.instance.client;

  bool _running = false;
  bool _runAgain = false;
  Timer? _debounce;
  Timer? _poller;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  /// Call once after Supabase.initialize().
  Future<void> start() async {
    await _authSub?.cancel();
    _authSub = _client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        _subscribeRealtime();
        scheduleSync();
      } else {
        _unsubscribeRealtime();
      }
    });

    // Picks up local edits (repositories don't notify the sync layer).
    _poller ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => scheduleSync(),
    );

    if (_client.auth.currentUser != null) {
      _subscribeRealtime();
      scheduleSync();
    }
  }

  void stop() {
    _poller?.cancel();
    _poller = null;
    _debounce?.cancel();
    _authSub?.cancel();
    _unsubscribeRealtime();
  }

  /// Debounced: many quick calls collapse into one sync.
  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    try {
      final changed = await _pull(user.id); // cloud -> local
      await _push(user.id); // local -> cloud
      // Only when the pull actually changed local data, refresh every screen.
      if (changed.isNotEmpty) {
        DataRefreshBus.instance.notify(RefreshScope.all);
      }
    } catch (e) {
      // Offline or server error: nothing is lost, the next run retries.
      debugPrint('Sync failed: $e');
    } finally {
      _running = false;
      if (_runAgain) {
        _runAgain = false;
        scheduleSync();
      }
    }
  }

  // ---------------------------------------------------------------- realtime

  void _subscribeRealtime() {
    _unsubscribeRealtime();
    final channel = _client.channel('study-architect-sync');
    for (final t in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t.name,
        callback: (_) => scheduleSync(),
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  void _unsubscribeRealtime() {
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
    _channel = null;
  }

  // -------------------------------------------------------------------- meta

  Future<String?> _getMeta(Database db, String key) async {
    final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _setMeta(Database db, String key, String value) {
    return db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -------------------------------------------------------------------- pull

  /// Downloads rows changed in the cloud since the last pull.
  /// Returns the names of local tables that were modified.
  Future<Set<String>> _pull(String uid) async {
    final db = await DatabaseService.instance.database;
    final touched = <String>{};

    for (final t in _tables) {
      final key = 'pull:$uid:${t.name}';
      var cursor = await _getMeta(db, key);

      while (true) {
        final base = _client.from(t.name).select();
        final rows = await (cursor == null ? base : base.gt('updatedAt', cursor))
            .order('updatedAt', ascending: true)
            .limit(_pageSize);

        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw);
          try {
            if (await _applyRemote(db, t, row)) touched.add(t.name);
          } catch (e) {
            debugPrint('Skipped ${t.name} row ${row['id']}: $e');
          }
          cursor = _iso(DateTime.parse(row['updatedAt'] as String));
        }

        if (cursor != null) await _setMeta(db, key, cursor);
        if (rows.length < _pageSize) break;
      }
    }
    return touched;
  }

  /// Applies one cloud row with last-write-wins. Returns true if the
  /// local table changed.
  Future<bool> _applyRemote(
    Database db,
    _SyncTable t,
    Map<String, dynamic> remote,
  ) async {
    final id = remote['id'] as String;
    final localId = t.intId ? int.parse(id) : id;
    final remoteAt = _iso(DateTime.parse(remote['updatedAt'] as String));

    final local = await db.query(
      t.name,
      columns: ['updatedAt'],
      where: 'id = ?',
      whereArgs: [localId],
    );
    final localAt = local.isEmpty ? null : local.first['updatedAt'] as String?;

    // Local copy is newer or identical: keep it.
    if (localAt != null && localAt.compareTo(remoteAt) >= 0) return false;

    // Cloud row was deleted.
    if (remote['deletedAt'] != null) {
      await db.delete(t.name, where: 'id = ?', whereArgs: [localId]);
      await db.delete(
        'sync_tombstones',
        where: 'tableName = ? AND rowId = ?',
        whereArgs: [t.name, id],
      );
      return local.isNotEmpty;
    }

    // Deleted locally after the cloud version was written: keep it deleted.
    final tomb = await db.query(
      'sync_tombstones',
      where: 'tableName = ? AND rowId = ?',
      whereArgs: [t.name, id],
    );
    if (tomb.isNotEmpty &&
        (tomb.first['deletedAt'] as String).compareTo(remoteAt) >= 0) {
      return false;
    }

    final values = Map<String, dynamic>.from(remote)
      ..remove('user_id')
      ..remove('deletedAt')
      ..['id'] = localId
      ..['updatedAt'] = remoteAt;

    if (local.isEmpty) {
      await db.insert(t.name, values);
    } else {
      // update, not "insert or replace": REPLACE would delete the row first
      // and cascade-delete its children.
      await db.update(t.name, values, where: 'id = ?', whereArgs: [localId]);
    }
    return true;
  }

  // -------------------------------------------------------------------- push

  Future<void> _push(String uid) async {
    final db = await DatabaseService.instance.database;

    // 1) New and edited rows.
    for (final t in _tables) {
      final key = 'push:$uid:${t.name}';
      final since = await _getMeta(db, key);

      final rows = await db.query(
        t.name,
        where: since == null ? null : 'updatedAt > ?',
        whereArgs: since == null ? null : [since],
        orderBy: 'updatedAt ASC',
      );
      if (rows.isEmpty) continue;

      final payload = rows
          .map((r) => <String, dynamic>{
                ...r,
                'id': r['id'].toString(),
                'user_id': uid,
                'deletedAt': null,
              })
          .toList();

      for (var i = 0; i < payload.length; i += 200) {
        final end = i + 200 > payload.length ? payload.length : i + 200;
        await _client
            .from(t.name)
            .upsert(payload.sublist(i, end), onConflict: 'user_id,id');
      }
      await _setMeta(db, key, rows.last['updatedAt'] as String);
    }

    // 2) Deletes.
    final tombstones = await db.query('sync_tombstones');
    for (final tomb in tombstones) {
      final table = tomb['tableName'] as String;
      final rowId = tomb['rowId'] as String;
      final at = tomb['deletedAt'] as String;

      await _client
          .from(table)
          .update({'deletedAt': at, 'updatedAt': at})
          .eq('user_id', uid)
          .eq('id', rowId);

      await db.delete(
        'sync_tombstones',
        where: 'tableName = ? AND rowId = ?',
        whereArgs: [table, rowId],
      );
    }
  }
}