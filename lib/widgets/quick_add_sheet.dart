import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/data_refresh_bus.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/task.dart';
import '../repositories/session_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/task_repository.dart';
import '../services/quick_add_parser.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import '../utils/date_utils.dart';

/// Opens the quick-add sheet. Returns true when a session or task was
/// created.
Future<bool> showQuickAddSheet(BuildContext context) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickAddSheet(),
  );
  return created ?? false;
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  static const _uuid = Uuid();
  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  static const _monthNames = [
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
  static const _durationChoices = [15, 30, 45, 60, 90, 120, 180, 240];

  final _inputCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  List<Subject> _subjects = const [];
  bool _loadingSubjects = true;
  QuickAddResult? _parsed;

  QuickAddKind _kind = QuickAddKind.session;
  String? _subjectId;
  DateTime _date = startOfDay(DateTime.now());
  int _startMinutes = 17 * 60;
  int _duration = 60;

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final list = await SubjectRepository().getAll();
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _loadingSubjects = false;
      });
      _onInputChanged(_inputCtrl.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSubjects = false;
        _error = 'Could not load your subjects.';
      });
    }
  }

  void _onInputChanged(String text) {
    final result = QuickAddParser.parse(text, subjects: _subjects);
    setState(() {
      if (!result.hasContent) {
        _parsed = null;
        return;
      }
      _parsed = result;
      _kind = result.kind;
      if (result.subject != null) {
        _subjectId = result.subject!.id;
      } else if (_subjectId != null &&
          !_subjects.any((s) => s.id == _subjectId)) {
        _subjectId = null;
      }
      if (_subjectId == null && _subjects.length == 1) {
        _subjectId = _subjects.first.id;
      }
      _date = result.date;
      _startMinutes = result.startMinutes;
      _duration = result.durationMinutes;
      _titleCtrl.text = result.title;
      _error = null;
    });
  }

  String _formatDate(DateTime d) =>
      '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  String _formatTime(int minutes) =>
      formatTimeOfDay(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = startOfDay(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinutes ~/ 60,
        minute: _startMinutes % 60,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _startMinutes = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    final parsed = _parsed;
    if (parsed == null) {
      setState(
          () => _error = 'Type something first, e.g. "Maths tomorrow 4pm 1h".');
      return;
    }
    final subjectId = _subjectId;
    if (subjectId == null) {
      setState(() => _error = 'Choose a subject.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_kind == QuickAddKind.session) {
        final window =
            QuickAddParser.sessionWindow(_date, _startMinutes, _duration);
        if (!window.valid) {
          setState(() {
            _saving = false;
            _error = 'The end time must be after the start time.';
          });
          return;
        }
        final session = StudySession(
          id: _uuid.v4(),
          subjectId: subjectId,
          scheduledDate: startOfDay(_date),
          startTime: window.start,
          endTime: window.end,
          notes: _titleCtrl.text.trim(),
        );
        await SessionRepository().create(session);
        DataRefreshBus.instance.notify(RefreshScope.sessions);
      } else {
        final title = _titleCtrl.text.trim();
        if (title.isEmpty) {
          setState(() {
            _saving = false;
            _error = 'Give the task a title.';
          });
          return;
        }
        final task = Task(
          id: _uuid.v4(),
          title: title,
          subjectId: subjectId,
          dueDate: startOfDay(_date),
          type: parsed.taskType,
          createdAt: DateTime.now(),
        );
        await TaskRepository().create(task);
        DataRefreshBus.instance.notify(RefreshScope.tasks);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  List<String> _hints() {
    final parsed = _parsed;
    if (parsed == null) return const [];
    final hints = <String>[];
    if (parsed.dateAssumed) hints.add('No date found, using today.');
    if (_kind == QuickAddKind.session) {
      if (parsed.timeAssumed) {
        hints.add('No time found, using ${_formatTime(parsed.startMinutes)}.');
      }
      if (parsed.durationAssumed) {
        hints.add(
            'No duration found, using ${formatDuration(parsed.durationMinutes)}.');
      }
      final window =
          QuickAddParser.sessionWindow(_date, _startMinutes, _duration);
      if (window.clamped) {
        hints.add('This would pass midnight, so it ends at 11:59 PM.');
      }
      if (window.start.isBefore(DateTime.now())) {
        hints.add('This time has already passed.');
      }
    }
    hints.addAll(parsed.warnings);
    return hints;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isSession = _kind == QuickAddKind.session;
    final durationOptions = {..._durationChoices, _duration}.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick add',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              TextField(
                controller: _inputCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: _onInputChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.auto_awesome_rounded),
                  hintText: 'e.g. Maths tomorrow 4pm 1h',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try "task: finish lab report friday" or "physics 18:30 for 90 min". Typing again resets the fields below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                ),
              ),
              if (_loadingSubjects) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ] else if (_subjects.isEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Add a subject first, then come back to quick add.',
                  style: theme.textTheme.bodyMedium,
                ),
              ] else if (_parsed != null) ...[
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<QuickAddKind>(
                  segments: const [
                    ButtonSegment(
                      value: QuickAddKind.session,
                      label: Text('Session'),
                      icon: Icon(Icons.timer_outlined),
                    ),
                    ButtonSegment(
                      value: QuickAddKind.task,
                      label: Text('Task'),
                      icon: Icon(Icons.check_circle_outline_rounded),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Choose subject'),
                  value: _subjectId,
                  items: [
                    for (final s in _subjects)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: isSession ? 'Notes (optional)' : 'Task title',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, size: 20),
                  title: Text(_formatDate(_date)),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
                  onTap: _pickDate,
                ),
                if (isSession) ...[
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded, size: 20),
                    title: Text(_formatTime(_startMinutes)),
                    trailing: const Icon(Icons.edit_rounded, size: 18),
                    onTap: _pickTime,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _duration,
                          items: [
                            for (final d in durationOptions)
                              DropdownMenuItem(
                                value: d,
                                child: Text(formatDuration(d)),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _duration = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                for (final hint in _hints())
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || _subjects.isEmpty) ? null : _save,
                  child: Text(isSession ? 'Add session' : 'Add task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
