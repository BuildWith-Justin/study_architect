import 'package:flutter/material.dart';

/// Everything the badges look at, gathered in one pass by the engine.
class GamificationStats {
  final int totalFocusMinutes;
  final int completedSessions;
  final int longestSessionMinutes;
  final int completedTasks;
  final int preparedExamTopics;
  final int examsFullyPrepared;
  final int currentStreak;
  final int bestStreak;
  final int level;
  final int totalXp;

  const GamificationStats({
    this.totalFocusMinutes = 0,
    this.completedSessions = 0,
    this.longestSessionMinutes = 0,
    this.completedTasks = 0,
    this.preparedExamTopics = 0,
    this.examsFullyPrepared = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.level = 1,
    this.totalXp = 0,
  });
}

/// A badge that can be unlocked. Only the id is stored in the database
/// (table achievements); the rest lives here in code, so new badges can
/// be added later and unlock from existing history.
class BadgeDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Value of [progress] needed to unlock the badge.
  final int target;

  /// Current value toward the target (also drives the progress bar of a
  /// locked badge on the Achievements screen).
  final int Function(GamificationStats stats) progress;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.progress,
  });

  bool isEarned(GamificationStats stats) => progress(stats) >= target;
}

final List<BadgeDef> kBadges = [
  BadgeDef(
    id: 'first_session',
    title: 'First step',
    description: 'Complete your first study session.',
    icon: Icons.flag,
    target: 1,
    progress: (s) => s.completedSessions,
  ),
  BadgeDef(
    id: 'sessions_10',
    title: 'Getting serious',
    description: 'Complete 10 study sessions.',
    icon: Icons.menu_book,
    target: 10,
    progress: (s) => s.completedSessions,
  ),
  BadgeDef(
    id: 'sessions_50',
    title: 'Regular',
    description: 'Complete 50 study sessions.',
    icon: Icons.auto_stories,
    target: 50,
    progress: (s) => s.completedSessions,
  ),
  BadgeDef(
    id: 'focus_10h',
    title: 'Ten hours in',
    description: 'Focus for 10 hours in total.',
    icon: Icons.timer,
    target: 600,
    progress: (s) => s.totalFocusMinutes,
  ),
  BadgeDef(
    id: 'focus_50h',
    title: 'Fifty hours',
    description: 'Focus for 50 hours in total.',
    icon: Icons.hourglass_bottom,
    target: 3000,
    progress: (s) => s.totalFocusMinutes,
  ),
  BadgeDef(
    id: 'focus_100h',
    title: 'Centurion',
    description: 'Focus for 100 hours in total.',
    icon: Icons.workspace_premium,
    target: 6000,
    progress: (s) => s.totalFocusMinutes,
  ),
  BadgeDef(
    id: 'deep_focus',
    title: 'Deep focus',
    description: 'Finish a single session of 60 minutes or more.',
    icon: Icons.self_improvement,
    target: 60,
    progress: (s) => s.longestSessionMinutes,
  ),
  BadgeDef(
    id: 'streak_3',
    title: 'On a roll',
    description: 'Reach a 3-day study streak.',
    icon: Icons.local_fire_department,
    target: 3,
    progress: (s) => s.bestStreak,
  ),
  BadgeDef(
    id: 'streak_7',
    title: 'Week warrior',
    description: 'Reach a 7-day study streak.',
    icon: Icons.local_fire_department,
    target: 7,
    progress: (s) => s.bestStreak,
  ),
  BadgeDef(
    id: 'streak_30',
    title: 'Unstoppable',
    description: 'Reach a 30-day study streak.',
    icon: Icons.whatshot,
    target: 30,
    progress: (s) => s.bestStreak,
  ),
  BadgeDef(
    id: 'tasks_10',
    title: 'Task crusher',
    description: 'Complete 10 tasks.',
    icon: Icons.task_alt,
    target: 10,
    progress: (s) => s.completedTasks,
  ),
  BadgeDef(
    id: 'tasks_50',
    title: 'Task machine',
    description: 'Complete 50 tasks.',
    icon: Icons.checklist,
    target: 50,
    progress: (s) => s.completedTasks,
  ),
  BadgeDef(
    id: 'exam_ready',
    title: 'Exam ready',
    description: 'Prepare every topic of one exam.',
    icon: Icons.school,
    target: 1,
    progress: (s) => s.examsFullyPrepared,
  ),
  BadgeDef(
    id: 'level_5',
    title: 'Level 5',
    description: 'Reach level 5.',
    icon: Icons.military_tech,
    target: 5,
    progress: (s) => s.level,
  ),
  BadgeDef(
    id: 'level_10',
    title: 'Level 10',
    description: 'Reach level 10.',
    icon: Icons.emoji_events,
    target: 10,
    progress: (s) => s.level,
  ),
];

BadgeDef? badgeById(String id) {
  for (final b in kBadges) {
    if (b.id == id) return b;
  }
  return null;
}
