/// A badge the student has already unlocked. The id is the badge key
/// defined in code (for example "streak_7"); the list of all possible
/// badges lives in the gamification engine, not in the database.
class Achievement {
  final String id;
  final DateTime unlockedAt;

  const Achievement({
    required this.id,
    required this.unlockedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id: map['id'] as String,
        unlockedAt: DateTime.parse(map['unlockedAt'] as String),
      );
}
