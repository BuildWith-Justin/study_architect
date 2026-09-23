import '../../models/subject.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';

/// A subject plus the two numbers its list-row card needs: how many
/// topics it has, and what fraction of them are completed.
class SubjectSummary {
  final Subject subject;
  final int topicCount;
  final int completionPercent;

  const SubjectSummary({
    required this.subject,
    required this.topicCount,
    required this.completionPercent,
  });

  static Future<List<SubjectSummary>> loadAll() async {
    final subjectRepo = SubjectRepository();
    final topicRepo = TopicRepository();

    final subjects = await subjectRepo.getAll();
    final summaries = <SubjectSummary>[];

    for (final subject in subjects) {
      final topics = await topicRepo.getForSubject(subject.id);
      final completed = topics.where((t) => t.completed).length;
      final percent = topics.isEmpty
          ? 0
          : ((completed / topics.length) * 100).round();
      summaries.add(SubjectSummary(
        subject: subject,
        topicCount: topics.length,
        completionPercent: percent,
      ));
    }

    return summaries;
  }
}