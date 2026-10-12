import 'package:flutter/material.dart';
import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
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

class _TimetableScreenState extends State<TimetableScreen>
    with RefreshableScreenMixin<TimetableScreen> {
  late DateTime _selectedDay;
  late Future<TimetableWeekData> _future;

  /// Last week of data that finished loading. Only used to draw the
  /// small "has sessions" dots under the day selector.
  TimetableWeekData? _loadedData;
  DateTime? _loadedWeekStart;

  /// Data scopes that make this screen reload itself automatically.
  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.sessions,
        RefreshScope.subjects,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
    _selectedDay = startOfDay(DateTime.now());
    _future = _load();
  }

  /// Loads the week that contains [_selectedDay] and remembers it for
  /// the day dots, but only if that week is still the one on screen.
  Future<TimetableWeekData> _load() {
    final weekStart = startOfWeek(_selectedDay);
    return TimetableWeekData.load(_selectedDay).then((data) {
      if (mounted && startOfWeek(_selectedDay) == weekStart) {
        setState(() {
          _loadedData = data;
          _loadedWeekStart = weekStart;
        });
      }
      return data;
    });
  }

  /// Used by pull-to-refresh, the retry button, the DataRefreshBus
  /// (a session was saved, deleted or synced) and "Today".
  @override
  Future<void> onRefresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // AsyncBuilder shows the error state with a retry button.
    }
  }

  void _selectDay(DateTime day) => setState(() => _selectedDay = day);

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _selectedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + 7 * deltaWeeks,
      );
      _future = _load();
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDay = startOfDay(DateTime.now());
      _future = _load();
    });
  }

  PastelHue _hueFor(int colorValue) {
    if (colorValue == AppColors.accentGreenStrong.value) return PastelHue.green;
    if (colorValue == AppColors.accentBlueStrong.value) return PastelHue.blue;
    return PastelHue.purple;
  }

  /// True when the week on screen has at least one session on [day].
  bool _hasSessionsOn(DateTime day) {
    final data = _loadedData;
    if (data == null) return false;
    if (_loadedWeekStart != startOfWeek(day)) return false;
    return data.forDay(day).isNotEmpty;
  }

  Future<void> _openCreate() async {
    // The session form notifies DataRefreshBus on save, which reloads
    // this screen through RefreshableScreenMixin.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditSessionScreen(initialDate: _selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(_selectedDay);
    final isOnToday = isSameDay(_selectedDay, DateTime.now());
    final bottomPadding = widget.standalone ? 24.0 : 96.0;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Timetable',
                  style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
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
              Flexible(
                child: Text(
                  _weekRangeLabel(weekStart),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.secondaryText,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
                onPressed: () => _shiftWeek(1),
              ),
              const Spacer(),
              if (!isOnToday)
                TextButton(
                  onPressed: _goToToday,
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DaySelector(
            weekStart: weekStart,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
            hasSessions: _hasSessionsOn,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AsyncBuilder<TimetableWeekData>(
              future: _future,
              errorMessage: 'Could not load your timetable.',
              onRetry: onRefresh,
              builder: (context, week) {
                final sessions = week.forDay(_selectedDay);

                if (sessions.isEmpty) {
                  return buildRefreshable(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: Text(
                              'No sessions this day — tap + to plan one.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: context.secondaryText),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return buildRefreshable(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final subject = week.subjectsById[session.subjectId];
                      final topic = session.topicId != null
                          ? week.topicsById[session.topicId]
                          : null;

                      final status = session.complete ? 'Completed' : 'Planned';

                      return TimelineEventCard(
                        timeRange:
                            '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
                        title: subject?.name ?? 'Unknown subject',
                        subtitle: topic?.name ?? 'Study session',
                        meta: session.isRecurring ? '$status · Weekly' : status,
                        hue: subject != null
                            ? _hueFor(subject.colorValue)
                            : PastelHue.blue,
                        isLast: index == sessions.length - 1,
                        onTap: () async {
                          // The session form notifies DataRefreshBus on
                          // save/delete, which reloads this screen.
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditSessionScreen(existing: session),
                            ),
                          );
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
              AppBar(
                  title: const Text('Timetable'), leading: const BackButton()),
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const shortMonths = [
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

    if (weekStart.month == weekEnd.month) {
      final month = months[weekStart.month - 1];
      return 'Week • $month ${weekStart.day}–${weekEnd.day}';
    }

    // The week crosses two months, e.g. "Sep 28 – Oct 4".
    final startMonth = shortMonths[weekStart.month - 1];
    final endMonth = shortMonths[weekEnd.month - 1];
    return 'Week • $startMonth ${weekStart.day} – $endMonth ${weekEnd.day}';
  }
}

class _DaySelector extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime day) hasSessions;

  const _DaySelector({
    required this.weekStart,
    required this.selectedDay,
    required this.onSelect,
    required this.hasSessions,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day =
            DateTime(weekStart.year, weekStart.month, weekStart.day + i);
        final selected = isSameDay(day, selectedDay);
        final isToday = isSameDay(day, DateTime.now());
        final busy = hasSessions(day);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(day),
          child: Column(
            children: [
              Text(
                _labels[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: AppColors.primary, width: 1.5)
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
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? AppColors.teal : Colors.transparent,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
