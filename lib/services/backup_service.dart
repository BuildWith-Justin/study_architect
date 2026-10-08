import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/achievement_repository.dart';
import '../repositories/exam_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/topic_repository.dart';
import '../repositories/xp_repository.dart';
import 'app_prefs.dart';
import 'database_service.dart';

/// The export/import format is each model's existing toMap() shape,
/// wrapped with a version tag. V2 Step 16 adds three optional keys
/// (avatarPath, preferences, appVersion); older backups simply do not
/// have them and older apps ignore them, so the version stays 1.
class BackupService {
  static const _currentVersion = 1;

  static const _countTables = {
    'subjects': 'subjects',
    'topics': 'topics',
    'sessions': 'study_sessions',
    'tasks': 'tasks',
    'exams': 'exams',
    'xpLog': 'xp_log',
    'achievements': 'achievements',
  };

  /// Gathers every table into one JSON-serializable map.
  Future<Map<String, dynamic>> buildBackupJson() async {
    final student = await StudentRepository().getCurrent();
    final settings = await SettingsRepository().get();
    final subjects = await SubjectRepository().getAll();

    final topics = <Map<String, dynamic>>[];
    final sessions = <Map<String, dynamic>>[];
    for (final subject in subjects) {
      final subjectTopics = await TopicRepository().getForSubject(subject.id);
      topics.addAll(subjectTopics.map((t) => t.toMap()));
      final subjectSessions =
          await SessionRepository().getForSubject(subject.id);
      sessions.addAll(subjectSessions.map((s) => s.toMap()));
    }

    final tasks = await TaskRepository().getAll();

    // V2 Step 11: exams and their topic checklists.
    final examRepo = ExamRepository();
    final exams = await examRepo.getAll();
    final examTopics = await examRepo.getAllTopicLinks();

    // V2 Step 13: XP ledger and unlocked badges.
    final xpLog = await XpRepository().getAll();
    final achievements = await AchievementRepository().getAll();

    return {
      'version': _currentVersion,
      'appVersion': 'V2',
      'exportedAt': DateTime.now().toIso8601String(),
      'student': student?.toMap(),
      'settings': settings.toMap(),
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'topics': topics,
      'sessions': sessions,
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'exams': exams.map((e) => e.toMap()).toList(),
      'examTopics': examTopics.map((l) => l.toMap()).toList(),
      'xpLog': xpLog.map((x) => x.toMap()).toList(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      // V2 Step 16: the profile photo link and the reminder preferences.
      'avatarPath': await _readAvatarPath(),
      'preferences': await AppPrefs.exportForBackup(),
    };
  }

  /// Reads the avatar path straight from the table, so it is saved
  /// whatever the Student model's toMap() does.
  Future<String?> _readAvatarPath() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery('SELECT avatarPath FROM students LIMIT 1');
      if (rows.isEmpty) return null;
      return rows.first['avatarPath'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Writes the backup JSON to a temp file and returns its path.
  Future<String> exportToFile() async {
    final json = await buildBackupJson();
    final dir = await getTemporaryDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/study_architect_backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return file.path;
  }

  /// Writes the backup and opens the OS share sheet. Returns false when
  /// the person closed the sheet without sharing.
  Future<bool> shareBackup() async {
    final path = await exportToFile();
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Study Architect backup'),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  /// Saves the current data next to the app before a restore replaces it.
  /// Returns the file path, or null if it could not be written.
  Future<String?> saveSafetyCopy() async {
    try {
      final json = await buildBackupJson();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/study_architect_before_restore.json');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Validates and parses backup JSON text. Throws FormatException
  /// with a human-readable message if it is not a Study Architect backup.
  Map<String, dynamic> parseBackup(String jsonText) {
    final text =
        jsonText.startsWith('\uFEFF') ? jsonText.substring(1) : jsonText;

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(
          'This file is not a valid Study Architect backup.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'This file is not a valid Study Architect backup.');
    }

    final version = decoded['version'];
    if (version == null) {
      throw const FormatException('This file is missing a version marker.');
    }
    if (version is! int) {
      throw const FormatException(
          'This file is not a valid Study Architect backup.');
    }
    if (version > _currentVersion) {
      throw const FormatException(
          'This backup was made by a newer version of the app.');
    }

    for (final key in const [
      'subjects',
      'topics',
      'sessions',
      'tasks',
      'exams',
      'examTopics',
      'xpLog',
      'achievements',
    ]) {
      final value = decoded[key];
      if (value != null && value is! List) {
        throw FormatException('The "$key" section of this backup is damaged.');
      }
    }
    return decoded;
  }

  /// How many items each section of a parsed backup holds.
  Map<String, int> describe(Map<String, dynamic> backup) {
    int count(String key) {
      final v = backup[key];
      return v is List ? v.length : 0;
    }

    return {
      'subjects': count('subjects'),
      'topics': count('topics'),
      'sessions': count('sessions'),
      'tasks': count('tasks'),
      'exams': count('exams'),
      'xpLog': count('xpLog'),
      'achievements': count('achievements'),
    };
  }

  /// Same counts, for the data currently stored on this device.
  Future<Map<String, int>> countLocal() async {
    final db = await DatabaseService.instance.database;
    final out = <String, int>{};
    for (final entry in _countTables.entries) {
      final rows =
          await db.rawQuery('SELECT COUNT(*) AS c FROM ${entry.value}');
      final c = rows.first['c'];
      out[entry.key] = c is int ? c : int.tryParse('$c') ?? 0;
    }
    return out;
  }

  /// Fully replaces local data with the contents of [backup].
  Future<void> restore(Map<String, dynamic> backup) async {
    await DatabaseService.instance.restoreFromBackup(
      student: (backup['student'] as Map?)?.cast<String, dynamic>(),
      settings: (backup['settings'] as Map?)?.cast<String, dynamic>(),
      subjects: _asMapList(backup['subjects']),
      topics: _asMapList(backup['topics']),
      sessions: _asMapList(backup['sessions']),
      tasks: _asMapList(backup['tasks']),
      exams: _asMapList(backup['exams']),
      examTopics: _asMapList(backup['examTopics']),
      xpLog: _asMapList(backup['xpLog']),
      achievements: _asMapList(backup['achievements']),
    );

    await _restoreAvatarPath(backup['avatarPath']);
    await _clearStaleTombstones();

    final prefs = backup['preferences'];
    if (prefs is Map) {
      await AppPrefs.importFromBackup(prefs.cast<String, dynamic>());
    }
  }

  Future<void> _restoreAvatarPath(dynamic value) async {
    if (value is! String || value.isEmpty) return;
    try {
      final db = await DatabaseService.instance.database;
      await db.execute('UPDATE students SET avatarPath = ?', [value]);
    } catch (_) {
      // The photo link is a nice-to-have; the restore itself succeeded.
    }
  }

  /// The restore deletes every row first, which can leave "deleted"
  /// markers for ids that were just inserted again. Those markers would
  /// make the next sync delete the restored rows in the cloud, so any
  /// marker whose row exists again is removed.
  Future<void> _clearStaleTombstones() async {
    try {
      final db = await DatabaseService.instance.database;
      const tables = [
        'students',
        'settings',
        'subjects',
        'topics',
        'study_sessions',
        'tasks',
        'exams',
        'exam_topics',
        'achievements',
        'xp_log',
      ];
      for (final t in tables) {
        await db.execute(
          'DELETE FROM sync_tombstones WHERE tableName = ? '
          'AND rowId IN (SELECT CAST(id AS TEXT) FROM $t)',
          [t],
        );
      }
    } catch (_) {
      // No tombstone table (or nothing to clean): nothing to do.
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
