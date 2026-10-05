enum SessionStatus { planned, inProgress, completed, missed }

SessionStatus statusFromString(String value) {
  return SessionStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => SessionStatus.planned,
  );
}

/// V2 Step 7: how a session repeats. Every occurrence of a repeating
/// session is stored as its own row; rows of one series share a seriesId.
enum SessionRecurrence { none, weekly }

SessionRecurrence recurrenceFromString(String value) {
  return SessionRecurrence.values.firstWhere(
    (r) => r.name == value,
    orElse: () => SessionRecurrence.none,
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
  final SessionRecurrence recurrence;
  final DateTime? recurrenceUntil; // last day of the series (inclusive)
  final String? seriesId; // shared by every occurrence of one series

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
    this.recurrence = SessionRecurrence.none,
    this.recurrenceUntil,
    this.seriesId,
  });

  /// Business rule: a session cannot be saved with an end time earlier
  /// than or equal to its start time.
  bool get isTimeRangeValid => endTime.isAfter(startTime);

  /// True when this session is one occurrence of a repeating series.
  bool get isRecurring => seriesId != null;

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
    SessionRecurrence? recurrence,
    DateTime? recurrenceUntil,
    String? seriesId,
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
      recurrence: recurrence ?? this.recurrence,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      seriesId: seriesId ?? this.seriesId,
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
        'recurrence': recurrence.name,
        'recurrenceUntil': recurrenceUntil?.toIso8601String(),
        'seriesId': seriesId,
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
        // Older rows and older backups have no recurrence columns.
        recurrence:
            recurrenceFromString(map['recurrence'] as String? ?? 'none'),
        recurrenceUntil: map['recurrenceUntil'] == null
            ? null
            : DateTime.parse(map['recurrenceUntil'] as String),
        seriesId: map['seriesId'] as String?,
      );
}
