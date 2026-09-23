import 'package:sqflite/sqflite.dart';
import '../models/settings.dart';
import '../services/database_service.dart';

/// Single-row settings table (id is always 0).
class SettingsRepository {
  final _db = DatabaseService.instance;

  Future<AppSettings> get() async {
    final db = await _db.database;
    final rows = await db.query('settings', where: 'id = 0');
    if (rows.isEmpty) return const AppSettings();
    return AppSettings.fromMap(rows.first);
  }

  Future<void> save(AppSettings settings) async {
    final db = await _db.database;
    final map = settings.toMap()..['id'] = 0;
    await db.insert(
      'settings',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}