import 'package:flutter/foundation.dart';

import '../models/insight.dart';
import '../repositories/exam_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/task_repository.dart';
import 'insight_snooze_store.dart';
import 'insights_engine.dart';

/// Loads the data, runs the engine and hides snoozed insights.
/// This is what the screens call.
class InsightsService {
  InsightsService._();

  /// Never throws: on any error it returns an empty list, so a problem
  /// here can never break Home or Progress.
  static Future<List<Insight>> load({DateTime? now, int limit = 6}) async {
    try {
      final sessions = await SessionRepository().getAll();
      final subjects = await SubjectRepository().getAll();
      final tasks = await TaskRepository().getAll();
      final examRepo = ExamRepository();
      final exams = await examRepo.getUpcoming();
      final progress = await examRepo.getProgressForAll();

      final all = InsightsEngine.generate(
        sessions: sessions,
        subjects: subjects,
        tasks: tasks,
        exams: exams,
        examProgress: progress,
        now: now,
      );

      final snoozed = await InsightSnoozeStore.instance.activeIds(now: now);
      return all.where((i) => !snoozed.contains(i.id)).take(limit).toList();
    } catch (e, st) {
      debugPrint('InsightsService.load failed: $e\n$st');
      return const [];
    }
  }

  /// "Not now": hides the insight for its own snooze length.
  static Future<void> snooze(Insight insight) {
    return InsightSnoozeStore.instance.snooze(insight.id, insight.snooze);
  }
}
