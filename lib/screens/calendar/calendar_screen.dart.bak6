import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../app/route_observer.dart';
import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../models/exam.dart';
import '../../models/study_session.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/calendar_heat.dart';
import '../../utils/date_utils.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/timeline_event_card.dart';
import '../timetable/add_edit_session_screen.dart';
import 'calendar_view_data.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
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

String _dayTitle(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with RouteAware, RefreshableScreenMixin<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  CalendarViewData? _data;
  Object? _error;

  /// Only the newest load may write its result, so a slow load of an
  /// old month can never overwrite a newer one.
  int _requestId = 0;
  ModalRoute<dynamic>? _route;

  /// Data scopes that make this screen reload itself automatically.
  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.sessions,
        RefreshScope.subjects,
        RefreshScope.exams,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
    final today = startOfDay(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
    _loadMonth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route != null && route != _route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }

      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose(); // RefreshableScreenMixin cancels its subscription here.
  }

  @override
  void didPopNext() {
    // A screen above the calendar just closed, so data may have changed.
    onRefresh();
  }

  Future<void> _loadMonth() async {
    final id = ++_requestId;
    final month = DateTime(_focusedDay.year, _focusedDay.month, 1);

    try {
      final data = await CalendarViewData.load(month);
      if (!mounted || id != _requestId) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = e);
    }
  }

  /// Used by pull-to-refresh, the retry button, the DataRefreshBus and
  /// returning from another screen.
  @override
  Future<void> onRefresh() => _loadMonth();

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = startOfDay(selected);
      _focusedDay = focused;
    });
  }

  void _onPageChanged(DateTime focused) {
    final today = startOfDay(DateTime.now());

    setState(() {
      _focusedDay = focused;

      final selectedInMonth = _selectedDay.year == focused.year &&
          _selectedDay.month == focused.month;
      if (!selectedInMonth) {
        final todayInMonth =
            today.year == focused.year && today.month == focused.month;
        _selectedDay =
            todayInMonth ? today : DateTime(focused.year, focused.month, 1);
      }
    });

    _loadMonth();
  }

  void _goToToday() {
    final today = startOfDay(DateTime.now());
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
    _loadMonth();
  }

  Future<void> _openCreate() async {
    // The session form notifies DataRefreshBus on save, which reloads
    // this screen.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditSessionScreen(initialDate: _selectedDay),
      ),
    );
  }

  PastelHue _hueFor(int colorValue) {
    if (colorValue == AppColors.accentGreenStrong.value) return PastelHue.green;
    if (colorValue == AppColors.accentBlueStrong.value) return PastelHue.blue;
    return PastelHue.purple;
  }

  Color _heatColor(int level) {
    switch (level) {
      case 1:
        return AppColors.primary.withValues(alpha: 0.35);
      case 2:
        return AppColors.primary.withValues(alpha: 0.6);
      case 3:
        return AppColors.primary.withValues(alpha: 0.85);
      default:
        return AppColors.primaryDark;
    }
  }

  Widget _dot({Color? fill, Color? ring}) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: ring != null ? Border.all(color: ring, width: 1.5) : null,
      ),
    );
  }

  /// Dots under a day number: filled green = studied (darker = more),
  /// green ring = sessions planned but not completed, red = exam day.
  Widget? _buildMarker(DateTime day) {
    final data = _data;
    if (data == null) return null;

    final key = startOfDay(day);
    final level = heatLevel(data.studiedMinutesByDay[key] ?? 0);
    final hasPlanned = (data.sessionsByDay[key] ?? const <StudySession>[])
        .any((s) => !s.complete);
    final hasExam = data.examsByDay.containsKey(key);

    if (level == 0 && !hasPlanned && !hasExam) return null;

    final dots = <Widget>[];
    if (level > 0) {
      dots.add(_dot(fill: _heatColor(level)));
    } else if (hasPlanned) {
      dots.add(_dot(ring: AppColors.primary));
    }
    if (hasExam) {
      if (dots.isNotEmpty) dots.add(const SizedBox(width: 3));
      dots.add(_dot(fill: AppColors.danger));
    }

    return Positioned(
      bottom: 2,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: dots,
      ),
    );
  }

  bool _hasActivity(DateTime day) {
    final data = _data;
    if (data == null) return false;
    final key = startOfDay(day);
    return data.sessionsByDay.containsKey(key) ||
        data.examsByDay.containsKey(key);
  }

  Widget _sessionCard(CalendarViewData data, StudySession session, bool last) {
    final subject = data.subjectsById[session.subjectId];
    final topic =
        session.topicId != null ? data.topicsById[session.topicId] : null;
    final status = session.complete ? 'Completed' : 'Planned';

    return TimelineEventCard(
      timeRange:
          '${formatTimeOfDay(session.startTime)} - ${formatTimeOfDay(session.endTime)}',
      title: subject?.name ?? 'Unknown subject',
      subtitle: topic?.name ?? 'Study session',
      meta: session.isRecurring ? '$status · Weekly' : status,
      hue: subject != null ? _hueFor(subject.colorValue) : PastelHue.blue,
      isLast: last,
      onTap: () async {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => AddEditSessionScreen(existing: session),
          ),
        );
      },
    );
  }

  Widget _calendarCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: TableCalendar<int>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableGestures: AvailableGestures.horizontalSwipe,
        rowHeight: 56,
        daysOfWeekHeight: 28,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onPageChanged: _onPageChanged,
        eventLoader: (day) => _hasActivity(day) ? const [1] : const [],
        calendarBuilders: CalendarBuilders<int>(
          markerBuilder: (context, day, events) => _buildMarker(day),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.primaryText,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: context.primaryText,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: context.primaryText,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: context.secondaryText, fontSize: 12),
          weekendStyle: TextStyle(color: context.secondaryText, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          cellMargin: const EdgeInsets.fromLTRB(5, 5, 5, 12),
          defaultTextStyle: TextStyle(color: context.primaryText),
          weekendTextStyle: TextStyle(color: context.primaryText),
          outsideTextStyle: TextStyle(
            color: context.secondaryText.withValues(alpha: 0.5),
          ),
          todayDecoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, CalendarViewData? data) {
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall?.copyWith(
      color: context.secondaryText,
    );

    final text = data == null
        ? 'This month'
        : 'This month: ${formatDuration(data.monthMinutes)} · '
            '${data.monthStudyDays} study '
            '${data.monthStudyDays == 1 ? 'day' : 'days'}';

    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text('Less', style: small),
        const SizedBox(width: 4),
        for (var level = 1; level <= 4; level++) ...[
          _dot(fill: _heatColor(level)),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 1),
        Text('More', style: small),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final month = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final current = _data;
    // Only use data that belongs to the month on screen.
    final d =
        (current != null && current.focusedMonth == month) ? current : null;

    final sessions = d?.sessionsByDay[_selectedDay] ?? const <StudySession>[];
    final exams = d?.examsByDay[_selectedDay] ?? const <Exam>[];
    final studied = d?.studiedMinutesByDay[_selectedDay] ?? 0;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Calendar'),
                leading: const BackButton(),
                actions: [
                  TextButton(
                    onPressed: _goToToday,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Today'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
              Expanded(
                child: buildRefreshable(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Could not load calendar data.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: onRefresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      _calendarCard(context),
                      const SizedBox(height: AppSpacing.md),
                      _summaryRow(context, d),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dayTitle(_selectedDay),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openCreate,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add session'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (studied > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'Studied ${formatDuration(studied)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      if (d == null && _error == null)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (sessions.isEmpty && exams.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Text(
                            'Nothing scheduled on this day.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        )
                      else ...[
                        for (final exam in exams)
                          _ExamTile(
                            exam: exam,
                            subjectName:
                                d!.subjectsById[exam.subjectId]?.name ??
                                    'Unknown subject',
                          ),
                        for (var i = 0; i < sessions.length; i++)
                          _sessionCard(
                              d!, sessions[i], i == sessions.length - 1),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One exam on the selected day (read-only; open it from the Exams list).
class _ExamTile extends StatelessWidget {
  final Exam exam;
  final String subjectName;

  const _ExamTile({required this.exam, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      subjectName,
      formatTimeOfDay(exam.examDate),
      if (exam.location.isNotEmpty) exam.location,
    ].join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam: ${exam.title}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
