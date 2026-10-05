import '../../models/exam.dart';
import '../../models/subject.dart';
import '../../repositories/exam_repository.dart';
import '../../repositories/subject_repository.dart';

/// An exam plus the two things every list row needs: its subject and
/// how far along its preparation checklist is.
class ExamSummary {
  final Exam exam;
  final Subject? subject;
  final ExamProgress progress;

  const ExamSummary({
    required this.exam,
    required this.subject,
    required this.progress,
  });
}

/// Everything the exams list needs, loaded in one pass.
class ExamsViewData {
  /// From today onwards, nearest first.
  final List<ExamSummary> upcoming;

  /// Exam day already gone by, most recent first.
  final List<ExamSummary> past;

  const ExamsViewData({required this.upcoming, required this.past});

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
  int get totalCount => upcoming.length + past.length;

  static Future<ExamsViewData> load() async {
    final examRepo = ExamRepository();
    final exams = await examRepo.getAll();
    final subjects = await SubjectRepository().getAll();
    final progress = await examRepo.getProgressForAll();
    final subjectsById = {for (final s in subjects) s.id: s};

    final upcoming = <ExamSummary>[];
    final past = <ExamSummary>[];

    for (final exam in exams) {
      final summary = ExamSummary(
        exam: exam,
        subject: subjectsById[exam.subjectId],
        progress: progress[exam.id] ?? const ExamProgress.empty(),
      );
      if (exam.isPast()) {
        past.add(summary);
      } else {
        upcoming.add(summary);
      }
    }

    past.sort((a, b) => b.exam.examDate.compareTo(a.exam.examDate));
    return ExamsViewData(upcoming: upcoming, past: past);
  }
}
