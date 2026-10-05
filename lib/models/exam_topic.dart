/// Links one topic to one exam and remembers whether the student has
/// prepared it for that exam. The same topic can be ticked in one exam
/// and not in another, so this is separate from Topic.completed.
class ExamTopic {
  final String id;
  final String examId;
  final String topicId;
  final bool prepared;

  const ExamTopic({
    required this.id,
    required this.examId,
    required this.topicId,
    this.prepared = false,
  });

  ExamTopic copyWith({
    String? id,
    String? examId,
    String? topicId,
    bool? prepared,
  }) {
    return ExamTopic(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      topicId: topicId ?? this.topicId,
      prepared: prepared ?? this.prepared,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'examId': examId,
        'topicId': topicId,
        'prepared': prepared ? 1 : 0,
      };

  factory ExamTopic.fromMap(Map<String, dynamic> map) => ExamTopic(
        id: map['id'] as String,
        examId: map['examId'] as String,
        topicId: map['topicId'] as String,
        prepared: (map['prepared'] as int) == 1,
      );
}
