enum TaskType { assignment, reading, revision, project, other }

TaskType taskTypeFromString(String value) {
  return TaskType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TaskType.other,
  );
}

class Task {
  final String id;
  final String title;
  final String subjectId;
  final String? topicId;
  final DateTime dueDate;
  final TaskType type;
  final String notes;
  final bool completed;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    required this.subjectId,
    this.topicId,
    required this.dueDate,
    this.type = TaskType.other,
    this.notes = '',
    this.completed = false,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? subjectId,
    String? topicId,
    DateTime? dueDate,
    TaskType? type,
    String? notes,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subjectId': subjectId,
        'topicId': topicId,
        'dueDate': dueDate.toIso8601String(),
        'type': type.name,
        'notes': notes,
        'completed': completed ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        title: map['title'] as String,
        subjectId: map['subjectId'] as String,
        topicId: map['topicId'] as String?,
        dueDate: DateTime.parse(map['dueDate'] as String),
        type: taskTypeFromString(map['type'] as String),
        notes: map['notes'] as String? ?? '',
        completed: (map['completed'] as int) == 1,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}