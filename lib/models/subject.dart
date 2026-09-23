enum SubjectDifficulty { easy, medium, hard }

SubjectDifficulty difficultyFromString(String value) {
  return SubjectDifficulty.values.firstWhere(
    (d) => d.name == value,
    orElse: () => SubjectDifficulty.medium,
  );
}

class Subject {
  final String id;
  final String name;
  final SubjectDifficulty difficulty;
  final int colorValue; // ARGB int, e.g. AppColors.accentPurpleStrong.value
  final int weeklyTargetMinutes;
  final DateTime createdAt;

  const Subject({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.colorValue,
    required this.weeklyTargetMinutes,
    required this.createdAt,
  });

  Subject copyWith({
    String? id,
    String? name,
    SubjectDifficulty? difficulty,
    int? colorValue,
    int? weeklyTargetMinutes,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      colorValue: colorValue ?? this.colorValue,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'difficulty': difficulty.name,
        'colorValue': colorValue,
        'weeklyTargetMinutes': weeklyTargetMinutes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'] as String,
        name: map['name'] as String,
        difficulty: difficultyFromString(map['difficulty'] as String),
        colorValue: map['colorValue'] as int,
        weeklyTargetMinutes: map['weeklyTargetMinutes'] as int,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}