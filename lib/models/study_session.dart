enum SessionStatus { planned, inProgress, completed, missed }

SessionStatus statusFromString(String value) {
  return SessionStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => SessionStatus.planned,
  );
}

class StudySession {
  final String id;
  final String subjectId;
  final String? topicId;
  final DateTime scheduledDate;
  final DateTime startTime;
  final DateTime endTime;
  final int? actualDuration; // minutes, filled in once a session runs
  final SessionStatus status;
  final String notes;
  final int? rating; // 1-5, optional, set at session end
  final bool complete;

  const StudySession({
    required this.id,
    required this.subjectId,
    this.topicId,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    this.actualDuration,
    this.status = SessionStatus.planned,
    this.notes = '',
    this.rating,
    this.complete = false,
  });

  /// Business rule: a session cannot be saved with an end time earlier
  /// than or equal to its start time.
  bool get isTimeRangeValid => endTime.isAfter(startTime);

  StudySession copyWith({
    String? id,
    String? subjectId,
    String? topicId,
    DateTime? scheduledDate,
    DateTime? startTime,
    DateTime? endTime,
    int? actualDuration,
    SessionStatus? status,
    String? notes,
    int? rating,
    bool? complete,
  }) {
    return StudySession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      actualDuration: actualDuration ?? this.actualDuration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      complete: complete ?? this.complete,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'topicId': topicId,
        'scheduledDate': scheduledDate.toIso8601String(),
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'actualDuration': actualDuration,
        'status': status.name,
        'notes': notes,
        'rating': rating,
        'complete': complete ? 1 : 0,
      };

  factory StudySession.fromMap(Map<String, dynamic> map) => StudySession(
        id: map['id'] as String,
        subjectId: map['subjectId'] as String,
        topicId: map['topicId'] as String?,
        scheduledDate: DateTime.parse(map['scheduledDate'] as String),
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: DateTime.parse(map['endTime'] as String),
        actualDuration: map['actualDuration'] as int?,
        status: statusFromString(map['status'] as String),
        notes: map['notes'] as String? ?? '',
        rating: map['rating'] as int?,
        complete: (map['complete'] as int) == 1,
      );
}