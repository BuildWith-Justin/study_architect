import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Tue, 20 Oct 2026"
String examDateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Tue, 20 Oct"
String examShortDateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "09:05" (24-hour clock)
String examTimeLabel(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// "Past", "Today", "Tomorrow" or "12 days".
String daysLeftLabel(int days) {
  if (days < 0) return 'Past';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return '$days days';
}

enum ExamUrgency { calm, soon, urgent, past }

/// More than 14 days away is calm, 14 or fewer is soon, 3 or fewer is
/// urgent, and an exam day that has gone by is past.
ExamUrgency examUrgency(int daysLeft) {
  if (daysLeft < 0) return ExamUrgency.past;
  if (daysLeft <= 3) return ExamUrgency.urgent;
  if (daysLeft <= 14) return ExamUrgency.soon;
  return ExamUrgency.calm;
}

Color examUrgencyColor(BuildContext context, ExamUrgency urgency) {
  switch (urgency) {
    case ExamUrgency.calm:
      return AppColors.primary;
    case ExamUrgency.soon:
      return const Color(0xFFE08A00);
    case ExamUrgency.urgent:
      return const Color(0xFFD64545);
    case ExamUrgency.past:
      return context.secondaryText;
  }
}
