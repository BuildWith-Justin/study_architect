class Student {
  final String id;
  final String name;
  final String school;
  final String program;
  final String level;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;

  /// V2 Step 15: path of the profile photo in the Supabase 'avatars'
  /// bucket (null = no photo, the initial is shown instead).
  /// Read-only here: only AvatarService writes it, so it is deliberately
  /// NOT part of toMap(). Saving a Student can never erase the photo.
  final String? avatarPath;

  const Student({
    required this.id,
    required this.name,
    required this.school,
    required this.program,
    required this.level,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
    this.avatarPath,
  });

  Student copyWith({
    String? id,
    String? name,
    String? school,
    String? program,
    String? level,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    String? avatarPath,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      school: school ?? this.school,
      program: program ?? this.program,
      level: level ?? this.level,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'school': school,
        'program': program,
        'level': level,
        'dailyGoalMinutes': dailyGoalMinutes,
        'weeklyGoalMinutes': weeklyGoalMinutes,
      };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'] as String,
        name: map['name'] as String,
        school: map['school'] as String,
        program: map['program'] as String,
        level: map['level'] as String,
        dailyGoalMinutes: map['dailyGoalMinutes'] as int,
        weeklyGoalMinutes: map['weeklyGoalMinutes'] as int,
        avatarPath: map['avatarPath'] as String?,
      );
}
