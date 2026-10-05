/// An exam the student is preparing for (V2 Step 11).
class Exam {
  final String id;
  final String subjectId;
  final String title;

  /// Date and time of the exam, in the device's local time.
  final DateTime examDate;
  final String location;
  final String notes;
  final DateTime createdAt;

  const Exam({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.examDate,
    this.location = '',
    this.notes = '',
    required this.createdAt,
  });

  Exam copyWith({
    String? id,
    String? subjectId,
    String? title,
    DateTime? examDate,
    String? location,
    String? notes,
    DateTime? createdAt,
  }) {
    return Exam(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      examDate: examDate ?? this.examDate,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Whole calendar days from today to the exam day (0 = today,
  /// negative = already passed). The time of day is ignored.
  int daysLeft([DateTime? now]) {
    final today = now ?? DateTime.now();
    final todayDay = DateTime.utc(today.year, today.month, today.day);
    final examDay = DateTime.utc(examDate.year, examDate.month, examDate.day);
    return examDay.difference(todayDay).inDays;
  }

  /// True once the exam day is behind us.
  bool isPast([DateTime? now]) => daysLeft(now) < 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'examDate': examDate.toLocal().toIso8601String(),
        'location': location,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Exam.fromMap(Map<String, dynamic> map) => Exam(
        id: map['id'] as String,
        subjectId: map['subjectId'] as String,
        title: map['title'] as String,
        examDate: DateTime.parse(map['examDate'] as String),
        location: (map['location'] as String?) ?? '',
        notes: (map['notes'] as String?) ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}

/// How far along the preparation checklist of one exam is.
class ExamProgress {
  final int prepared;
  final int total;

  const ExamProgress({required this.prepared, required this.total});

  const ExamProgress.empty()
      : prepared = 0,
        total = 0;

  /// 0.0 to 1.0 (0 when the exam has no topics yet).
  double get fraction => total == 0 ? 0 : prepared / total;

  int get percent => (fraction * 100).round();
}
