import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/session_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/topic_repository.dart';
import 'database_service.dart';

/// The export/import format is just each model's existing toMap()
/// shape (the same one the repositories use for sqflite), wrapped
/// with a version tag — Step 3 built the models with this reuse in
/// mind from the start.
class BackupService {
  static const _currentVersion = 1;

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
      final subjectSessions = await SessionRepository().getForSubject(subject.id);
      sessions.addAll(subjectSessions.map((s) => s.toMap()));
    }

    final tasks = await TaskRepository().getAll();

    return {
      'version': _currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'student': student?.toMap(),
      'settings': settings.toMap(),
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'topics': topics,
      'sessions': sessions,
      'tasks': tasks.map((t) => t.toMap()).toList(),
    };
  }

  /// Writes the backup JSON to a temp file and returns its path, so
  /// callers can share it or otherwise hand it off to the OS.
  Future<String> exportToFile() async {
    final json = await buildBackupJson();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/study_architect_backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return file.path;
  }

  /// Writes the backup and opens the OS share sheet so the person can
  /// save it to Drive, Files, email it to themselves, etc. — there's
  /// no "export folder" concept needed since the share sheet handles
  /// wherever they actually want to put it.
  Future<void> shareBackup() async {
    final path = await exportToFile();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Study Architect backup'),
    );
  }

  /// Validates and parses backup JSON text. Throws FormatException
  /// with a human-readable message if it doesn't look like a Study
  /// Architect backup.
  Map<String, dynamic> parseBackup(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This file is not a valid Study Architect backup.');
    }
    if (decoded['version'] == null) {
      throw const FormatException('This file is missing a version marker.');
    }
    if (decoded['version'] > _currentVersion) {
      throw const FormatException('This backup was made by a newer version of the app.');
    }
    return decoded;
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
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}