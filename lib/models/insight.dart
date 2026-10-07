import 'package:flutter/material.dart';

/// What kind of suggestion this is (used for sorting and snooze length).
enum InsightKind {
  examPrep,
  overdueTasks,
  tasksDueToday,
  streakRisk,
  neglectedSubject,
  weeklyPace,
  bestTimeOfDay,
  weakDay,
  weeklyDrop,
  weeklyRise,
  firstSession,
}

/// Where the suggestion's button leads.
enum InsightAction { none, progress, tasks }

/// One pattern-based study suggestion, computed locally from the
/// student's own data (no network, no API cost).
class Insight {
  /// Stable id. Used to remember "Not now" (snooze).
  final String id;
  final InsightKind kind;
  final IconData icon;
  final String title;
  final String message;

  /// Higher = more important. Roughly 0-100.
  final int priority;
  final InsightAction action;
  final String actionLabel;

  /// How long "Not now" hides this insight.
  final Duration snooze;

  const Insight({
    required this.id,
    required this.kind,
    required this.icon,
    required this.title,
    required this.message,
    required this.priority,
    this.action = InsightAction.none,
    this.actionLabel = '',
    this.snooze = const Duration(days: 1),
  });
}
