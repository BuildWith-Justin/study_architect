import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Remembers which insights the student dismissed with "Not now", and
/// until when. Stored in a small JSON file next to the app data, so it
/// needs no database migration. If the file cannot be read or written,
/// the app keeps working (snoozes just last for the current session).
class InsightSnoozeStore {
  InsightSnoozeStore._();
  static final InsightSnoozeStore instance = InsightSnoozeStore._();

  Map<String, DateTime>? _cache;

  Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'insight_snoozes.json'));
    } catch (e) {
      debugPrint('InsightSnoozeStore: no storage folder: $e');
      return null;
    }
  }

  Future<Map<String, DateTime>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final result = <String, DateTime>{};
    try {
      final file = await _file();
      if (file != null && await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          raw.forEach((key, value) {
            final until = DateTime.tryParse('$value');
            if (until != null) result[key] = until;
          });
        }
      }
    } catch (e) {
      debugPrint('InsightSnoozeStore: could not read snoozes: $e');
    }
    _cache = result;
    return result;
  }

  Future<void> _save(Map<String, DateTime> data) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(jsonEncode({
        for (final e in data.entries) e.key: e.value.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('InsightSnoozeStore: could not save snoozes: $e');
    }
  }

  /// Ids that are hidden right now.
  Future<Set<String>> activeIds({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final data = await _load();
    return {
      for (final e in data.entries)
        if (e.value.isAfter(t)) e.key,
    };
  }

  /// Hides [id] for [duration].
  Future<void> snooze(String id, Duration duration, {DateTime? now}) async {
    final t = now ?? DateTime.now();
    final data = await _load();
    data.removeWhere((key, until) => !until.isAfter(t)); // tidy old entries
    data[id] = t.add(duration);
    await _save(data);
  }
}
