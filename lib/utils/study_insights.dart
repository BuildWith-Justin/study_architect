import 'package:flutter/material.dart';

class StudyInsight {
  final IconData icon;
  final String text;

  const StudyInsight({required this.icon, required this.text});
}

/// Deterministic, rule-based insights (no ML) — the V1 spec calls for
/// "rule-based study insights" specifically. Each rule is independent
/// and only fires when its condition is clearly true, so the list can
/// safely be empty on a quiet day.
List<StudyInsight> generateInsights({
  required int todayMinutes,
  required int weeklyMinutes,
  required int weeklyGoalMinutes,
  required int streak,
  required int longestStreak,
  required Map<String, int> subjectPerformancePercent,
}) {
  final insights = <StudyInsight>[];
  final now = DateTime.now();

  // Hasn't studied yet today, and the day is more than half over.
  if (todayMinutes == 0 && now.hour >= 15) {
    insights.add(const StudyInsight(
      icon: Icons.schedule_rounded,
      text: "You haven't studied yet today — even 20 minutes keeps your streak alive.",
    ));
  }

  // Behind pace on the weekly goal once the week is more than half done.
  if (weeklyGoalMinutes > 0 && now.weekday >= DateTime.thursday) {
    final progress = weeklyMinutes / weeklyGoalMinutes;
    if (progress < 0.5) {
      insights.add(StudyInsight(
        icon: Icons.trending_down_rounded,
        text:
            "You're at ${(progress * 100).round()}% of this week's goal with the week more than half over.",
      ));
    }
  }

  // Subjects clearly falling behind their own weekly target — collapsed
  // into a single line instead of one card per subject. Previously
  // this looped and added one insight *per* behind-target subject,
  // which meant a normal early-week state (nothing logged yet, so
  // every subject reads 0%) produced a card for every single subject
  // — pure noise, not an insight.
  final behindSubjects = subjectPerformancePercent.entries
      .where((e) => e.value < 40)
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  if (behindSubjects.isNotEmpty) {
    if (weeklyMinutes == 0 && behindSubjects.length == subjectPerformancePercent.length) {
      // Nothing logged at all yet this period — a single general
      // nudge is more useful than naming every subject.
      insights.add(const StudyInsight(
        icon: Icons.flag_outlined,
        text: "You haven't logged any study time yet this period.",
      ));
    } else {
      final shown = behindSubjects.take(2).map((e) => e.key).join(', ');
      final remaining = behindSubjects.length - 2;
      final verb = behindSubjects.length == 1 ? 'is' : 'are';
      final suffix = remaining > 0 ? ', and $remaining more,' : '';
      insights.add(StudyInsight(
        icon: Icons.flag_outlined,
        text: '$shown$suffix $verb behind on weekly targets.',
      ));
    }
  }

  // Reward consistency.
  if (streak >= 7) {
    insights.add(StudyInsight(
      icon: Icons.local_fire_department_rounded,
      text: "You're on a $streak-day streak — your longest is $longestStreak days.",
    ));
  } else if (streak == 0 && longestStreak > 0) {
    insights.add(StudyInsight(
      icon: Icons.replay_rounded,
      text: 'Your streak reset. Your best was $longestStreak days — start a new one today.',
    ));
  }

  return insights;
}