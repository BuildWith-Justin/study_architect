class Topic {
  final String id;
  final String subjectId;
  final String name;
  final bool completed;

  const Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    this.completed = false,
  });

  Topic copyWith({
    String? id,
    String? subjectId,
    String? name,
    bool? completed,
  }) {
    return Topic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'completed': completed ? 1 : 0,
      };

  factory Topic.fromMap(Map<String, dynamic> map) => Topic(
        id: map['id'] as String,
        subjectId: map['subjectId'] as String,
        name: map['name'] as String,
        completed: (map['completed'] as int) == 1,
      );
}