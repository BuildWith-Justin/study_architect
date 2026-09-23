class Student {
  final String id;
  final String name;
  final String school;
  final String program;
  final String level;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;

  const Student({
    required this.id,
    required this.name,
    required this.school,
    required this.program,
    required this.level,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
  });

  Student copyWith({
    String? id,
    String? name,
    String? school,
    String? program,
    String? level,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      school: school ?? this.school,
      program: program ?? this.program,
      level: level ?? this.level,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
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
      );
}