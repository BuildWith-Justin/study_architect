/// Every gamification number lives here, so the rules can be tuned in
/// one place after testing.
class XpRules {
  XpRules._();

  /// A session shorter than this earns nothing.
  static const int minSessionMinutes = 5;

  /// XP earned per focused minute of a completed session.
  static const int xpPerSessionMinute = 1;

  /// Most session XP that can be earned in one day.
  static const int dailySessionXpCap = 300;

  static const int taskXp = 10;
  static const int examTopicXp = 5;

  /// From this streak length on, session and task XP get a bonus.
  static const int streakBonusMinStreak = 3;
  static const int streakBonusPercent = 10;

  /// A day counts for the streak when at least this many minutes were
  /// studied (completed sessions, added up).
  static const int minStudyDayMinutes = 10;

  static const int maxLevel = 50;
}

/// XP before any bonus: 0 for a missing or too short session.
int sessionBaseXp(int? minutes) {
  final m = minutes ?? 0;
  if (m < XpRules.minSessionMinutes) return 0;
  return m * XpRules.xpPerSessionMinute;
}

/// Adds the streak bonus when [streak] is long enough.
/// Example: 25 XP at a 4-day streak -> 25 + 2.5 rounded = 28.
int applyStreakBonus(int baseXp, int streak) {
  if (baseXp <= 0 || streak < XpRules.streakBonusMinStreak) return baseXp;
  return baseXp + (baseXp * XpRules.streakBonusPercent / 100).round();
}

// XP needed to climb from level 2 to 3, 3 to 4, ... (first nine gaps).
// After that every level needs the same amount.
const List<int> _levelGaps = [100, 150, 250, 400, 600, 800, 1000, 1250, 1500];
const int _lateLevelGap = 2000;

/// Total XP needed to REACH [level]. Level 1 starts at 0.
/// 2 -> 100, 3 -> 250, 4 -> 500, 5 -> 900, 10 -> 6050.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  final target = level > XpRules.maxLevel ? XpRules.maxLevel : level;
  var total = 0;
  for (var l = 2; l <= target; l++) {
    final i = l - 2;
    total += i < _levelGaps.length ? _levelGaps[i] : _lateLevelGap;
  }
  return total;
}

class LevelInfo {
  final int level;
  final int totalXp;

  /// XP earned since this level started.
  final int xpIntoLevel;

  /// XP needed to go from this level to the next (0 at the top level).
  final int levelSize;

  const LevelInfo({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.levelSize,
  });

  bool get isMax => level >= XpRules.maxLevel;
  int get xpToNext => isMax ? 0 : levelSize - xpIntoLevel;
  double get progress =>
      (isMax || levelSize == 0) ? 1.0 : xpIntoLevel / levelSize;
}

LevelInfo levelForXp(int totalXp) {
  final xp = totalXp < 0 ? 0 : totalXp;
  var level = 1;
  while (level < XpRules.maxLevel && xp >= xpForLevel(level + 1)) {
    level++;
  }
  final start = xpForLevel(level);
  final size = level >= XpRules.maxLevel ? 0 : xpForLevel(level + 1) - start;
  return LevelInfo(
    level: level,
    totalXp: xp,
    xpIntoLevel: xp - start,
    levelSize: size,
  );
}

String levelTitle(int level) {
  if (level <= 2) return 'Starter';
  if (level <= 4) return 'Focused learner';
  if (level <= 9) return 'Dedicated';
  if (level <= 19) return 'Scholar';
  if (level <= 34) return 'Expert';
  return 'Master';
}
