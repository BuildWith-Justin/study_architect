class Topic {
  final String id;
  final String subjectId;
  final String name;
  final bool completed;

  /// Position of this topic in the subject's study roadmap (0 = first).
  final int sortOrder;

  const Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    this.completed = false,
    this.sortOrder = 0,
  });

  Topic copyWith({
    String? id,
    String? subjectId,
    String? name,
    bool? completed,
    int? sortOrder,
  }) {
    return Topic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'completed': completed ? 1 : 0,
        'sortOrder': sortOrder,
      };

  factory Topic.fromMap(Map<String, dynamic> map) => Topic(
        id: map['id'] as String,
        subjectId: map['subjectId'] as String,
        name: map['name'] as String,
        completed: (map['completed'] as int) == 1,
        // Older backups have no sortOrder, so fall back to 0.
        sortOrder: (map['sortOrder'] as int?) ?? 0,
      );
}
