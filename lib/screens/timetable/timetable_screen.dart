import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
// ignore: unused_import
import '../../models/subject.dart';
import '../../widgets/timeline_event_card.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/async_builder.dart';
import '../../widgets/gradient_background.dart';
import '../../utils/date_utils.dart';
import 'timetable_view_data.dart';
import 'add_edit_session_screen.dart';

class TimetableScreen extends StatefulWidget {
  /// True when this screen is pushed on its own (e.g. from Home's
  /// "View all") rather than shown as a tab body inside MainScaffold.
  /// MainScaffold already supplies the gradient background and bottom
  /// nav for the tab case, so this screen must not duplicate that —
  /// but a standalone push needs its own Scaffold, background, and
  /// back button, or it renders on a bare, unstyled surface.
  final bool standalone;

  const TimetableScreen({super.key, this.standalone = false});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late DateTime _selectedDay;
  late Future<TimetableWeekData> _future;

  @override
  void initState() {
    super.initState();
    _selectedDay = startOfDay(DateTime.now());
    _future = TimetableWeekData.load(_selectedDay);
  }

  /// Awaitable so both manual reload-after-edit calls and
  /// pull-to-refresh can use the same method.
  Future<void> _reload() async {
    final next = TimetableWeekData.load(_selectedDay);
    setState(() => _future = next);
    await next;
  }

  void _selectDay(DateTime day) => setState(() => _selectedDay = day);

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: 7 * deltaWeeks));
      _future = TimetableWeekData.load(_selectedDay);
    });
  }

  PastelHue _hueFor(int colorValue) {
    if (colorValue == AppColors.accentGreenStrong.value) return PastelHue.green;
    if (colorValue == AppColors.accentBlueStrong.value) return PastelHue.blue;
    return PastelHue.purple;
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditSessionScreen(initialDate: _selectedDay),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(_selectedDay);

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Timetable', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, size: 28),
                tooltip: 'Plan a session',
                onPressed: _openCreate,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous week',
                onPressed: () => _shiftWeek(-1),
              ),
              Text(
                _weekRangeLabel(weekStart),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
                onPressed: () => _shiftWeek(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DaySelector(
            weekStart: weekStart,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AsyncBuilder<TimetableWeekData>(
              future: _future,
              errorMessage: 'Could not load your timetable.',
              onRetry: _reload,
              builder: (context, week) {
                final sessions = week.forDay(_selectedDay);

                if (sessions.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: Text(
                              'No sessions this day — tap + to plan one.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final subject = week.subjectsById[session.subjectId];
                    final topic = session.topicId != null ? week.topicsById[session.topicId] : null;

                    return TimelineEventCard(
                      timeRange: '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
                      title: subject?.name ?? 'Unknown subject',
                      subtitle: topic?.name ?? 'Study session',
                      meta: session.complete ? 'Completed' : 'Planned',
                      hue: subject != null ? _hueFor(subject.colorValue) : PastelHue.blue,
                      isLast: index == sessions.length - 1,
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AddEditSessionScreen(existing: session),
                          ),
                        );
                        if (changed == true) _reload();
                      },
                    );
                  },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!widget.standalone) return content;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(title: const Text('Timetable'), leading: const BackButton()),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month = months[weekStart.month - 1];
    return 'Week • $month ${weekStart.day}–${weekEnd.day}';
  }
}

class _DaySelector extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  const _DaySelector({
    required this.weekStart,
    required this.selectedDay,
    required this.onSelect,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final selected = isSameDay(day, selectedDay);
        final isToday = isSameDay(day, DateTime.now());

        return GestureDetector(
          onTap: () => onSelect(day),
          child: Column(
            children: [
              Text(
                _labels[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentPurpleStrong : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: AppColors.accentPurpleStrong, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: selected ? Colors.white : context.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}