import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/data_refresh_bus.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../services/notification_service.dart';
import '../../gamification/gamification_hooks.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../utils/session_recurrence.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/app_buttons.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Phones limit how many local notifications can be pending at once,
/// so a long weekly series only schedules reminders for its first
/// occurrences.
const _maxReminders = 20;

enum _DeleteChoice { cancel, onlyThis, thisAndFollowing }

/// Handles both creating a session (pass no [existing]) and editing
/// one. [initialDate] pre-selects a date for new sessions (e.g. the
/// day currently selected on the Timetable screen). Pops `true` on
/// save/delete so the caller knows to reload.
///
/// V2 Step 7: a new session (or an existing one-off session) can be
/// repeated weekly. Every weekly occurrence is saved as its own row,
/// all sharing one seriesId.
class AddEditSessionScreen extends StatefulWidget {
  final StudySession? existing;
  final DateTime? initialDate;

  const AddEditSessionScreen({
    super.key,
    this.existing,
    this.initialDate,
  });

  @override
  State<AddEditSessionScreen> createState() => _AddEditSessionScreenState();
}

class _AddEditSessionScreenState extends State<AddEditSessionScreen> {
  final _subjectRepo = SubjectRepository();
  final _topicRepo = TopicRepository();
  final _sessionRepo = SessionRepository();
  final _notesController = TextEditingController();

  List<Subject> _subjects = [];
  List<Topic> _topics = [];

  String? _subjectId;
  String? _topicId;

  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  bool _repeatWeekly = false;
  late DateTime _repeatUntil;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  /// True when the session being edited is already part of a series.
  bool get _isRecurringExisting => widget.existing?.isRecurring ?? false;

  /// Last allowed "repeat until" day: 52 weekly occurrences in total.
  DateTime get _maxRepeatUntil => DateTime(
        _date.year,
        _date.month,
        _date.day + 7 * (kMaxWeeklyOccurrences - 1),
      );

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _date = existing?.scheduledDate ?? widget.initialDate ?? DateTime.now();

    // Default series length: 12 weekly sessions.
    _repeatUntil = DateTime(_date.year, _date.month, _date.day + 77);

    _startTime = existing != null
        ? TimeOfDay.fromDateTime(existing.startTime)
        : const TimeOfDay(hour: 16, minute: 0);

    _endTime = existing != null
        ? TimeOfDay.fromDateTime(existing.endTime)
        : const TimeOfDay(hour: 18, minute: 0);

    _subjectId = existing?.subjectId;
    _topicId = existing?.topicId;
    _notesController.text = existing?.notes ?? '';

    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _subjectRepo.getAll();

      if (!mounted) return;

      setState(() {
        _subjects = subjects;
        _subjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
        _loading = false;
      });

      if (_subjectId != null) {
        await _loadTopics(_subjectId!);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load subjects.';
      });
    }
  }

  Future<void> _loadTopics(String subjectId) async {
    try {
      final topics = await _topicRepo.getForSubject(subjectId);

      if (!mounted) return;

      setState(() {
        _topics = topics;

        if (!_topics.any((t) => t.id == _topicId)) {
          _topicId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _topics = [];
        _topicId = null;
      });
    }
  }

  DateTime _combine(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _weekdayName(DateTime d) => _weekdayNames[d.weekday - 1];

  String get _repeatSummary {
    final count = countWeeklyOccurrences(_date, _repeatUntil);
    final sessionsLabel = count == 1 ? '1 session' : '$count sessions';
    return '$sessionsLabel · every ${_weekdayName(_date)} until ${_formatDate(_repeatUntil)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final oneYearAgo = startOfDay(now.subtract(const Duration(days: 365)));
    final oneYearAhead = startOfDay(now.add(const Duration(days: 365)));
    final current = startOfDay(_date);

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: current.isBefore(oneYearAgo) ? current : oneYearAgo,
      lastDate: current.isAfter(oneYearAhead) ? current : oneYearAhead,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _date = picked;

      // Keep "repeat until" valid for the new start date.
      if (_repeatUntil.isBefore(picked)) {
        _repeatUntil = DateTime(picked.year, picked.month, picked.day + 77);
      }
      final maxUntil = _maxRepeatUntil;
      if (_repeatUntil.isAfter(maxUntil)) {
        _repeatUntil = maxUntil;
      }
    });
  }

  Future<void> _pickRepeatUntil() async {
    final first = startOfDay(_date);
    final last = _maxRepeatUntil;
    var initial = startOfDay(_repeatUntil);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Repeat until',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _repeatUntil = picked;
    });
  }

  Future<void> _pickTime({
    required bool isStart,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  /// Reminders are a nice-to-have: a failure here must never make a
  /// successful save look like a failed one.
  Future<void> _scheduleReminders(List<StudySession> sessions) async {
    try {
      if (_subjects.isEmpty) return;
      final subject = _subjects.firstWhere(
        (s) => s.id == sessions.first.subjectId,
        orElse: () => _subjects.first,
      );

      final now = DateTime.now();
      var scheduled = 0;
      for (final s in sessions) {
        if (s.startTime.isBefore(now)) continue;
        if (scheduled >= _maxReminders) break;
        await NotificationService.instance.scheduleSessionReminder(
          sessionId: s.id,
          subjectName: subject.name,
          sessionStart: s.startTime,
        );
        scheduled++;
      }
    } catch (_) {
      // Ignored on purpose, see above.
    }
  }

  Future<void> _cancelReminders(List<String> sessionIds) async {
    try {
      for (final id in sessionIds) {
        await NotificationService.instance.cancelSessionReminder(id);
      }
    } catch (_) {
      // Ignored on purpose: the session itself is already deleted.
    }
  }

  Future<void> _save() async {
    if (_subjectId == null) {
      setState(() {
        _error = 'Choose a subject first.';
      });
      return;
    }

    final start = _combine(
      _date,
      _startTime,
    );

    final end = _combine(
      _date,
      _endTime,
    );

    final existing = widget.existing;

    final base = StudySession(
      id: existing?.id ?? const Uuid().v4(),
      subjectId: _subjectId!,
      topicId: _topicId,
      scheduledDate: startOfDay(_date),
      startTime: start,
      endTime: end,
      notes: _notesController.text.trim(),
      status: existing?.status ?? SessionStatus.planned,
      complete: existing?.complete ?? false,
      actualDuration: existing?.actualDuration,
      rating: existing?.rating,
      recurrence: existing?.recurrence ?? SessionRecurrence.none,
      recurrenceUntil: existing?.recurrenceUntil,
      seriesId: existing?.seriesId,
    );

    if (!base.isTimeRangeValid) {
      setState(() {
        _error = 'End time must be after start time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final makeSeries = _repeatWeekly && !_isRecurringExisting;
      List<StudySession> toRemind;

      if (makeSeries) {
        final series = buildWeeklySeries(first: base, until: _repeatUntil);

        // Keep every field of the session being edited (status, rating,
        // notes...) on the first occurrence; the others start fresh.
        final firstSaved = base.copyWith(
          recurrence: SessionRecurrence.weekly,
          recurrenceUntil: startOfDay(_repeatUntil),
          seriesId: series.first.seriesId,
        );
        final all = [firstSaved, ...series.skip(1)];

        if (_isEditing) {
          await _sessionRepo.update(firstSaved);
          if (all.length > 1) {
            await _sessionRepo.createMany(all.sublist(1));
          }
        } else {
          await _sessionRepo.createMany(all);
        }
        toRemind = all;
      } else {
        if (_isEditing) {
          await _sessionRepo.update(base);
        } else {
          await _sessionRepo.create(base);
        }
        toRemind = [base];
      }

      await _scheduleReminders(toRemind);

      // V2 Step 13: a completed session that was edited (for example moved
      // to another day) keeps its XP in line.
      if (_isEditing && base.complete) {
        await GamificationHooks.sessionCompleted(base);
      }

      DataRefreshBus.instance.notify(RefreshScope.sessions);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save the session. Please try again.';
      });
    }
  }

  Future<_DeleteChoice> _askDeleteChoice() async {
    final existing = widget.existing!;

    if (!existing.isRecurring) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete session?'),
          content: const Text(
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      );
      return confirmed == true ? _DeleteChoice.onlyThis : _DeleteChoice.cancel;
    }

    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recurring session?'),
        content: const Text(
          'This session is part of a weekly series. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.onlyThis),
            child: const Text(
              'Only this session',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _DeleteChoice.thisAndFollowing,
            ),
            child: const Text(
              'This and following',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return choice ?? _DeleteChoice.cancel;
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final choice = await _askDeleteChoice();

    if (choice == _DeleteChoice.cancel) return;

    try {
      if (choice == _DeleteChoice.thisAndFollowing &&
          existing.seriesId != null) {
        final removed = await _sessionRepo.deleteSeries(
          existing.seriesId!,
          fromDate: existing.scheduledDate,
        );
        await _cancelReminders(removed.map((s) => s.id).toList());
        await GamificationHooks.sessionsRemoved(
          removed.map((s) => s.id).toList(),
        );
      } else {
        await _sessionRepo.delete(existing.id);
        await _cancelReminders([existing.id]);
        await GamificationHooks.sessionRemoved(existing.id);
      }

      DataRefreshBus.instance.notify(RefreshScope.sessions);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not delete the session. Please try again.';
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return time.format(context);
  }

  Widget _buildRepeatSection() {
    final theme = Theme.of(context);

    if (_isRecurringExisting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.cardSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.repeat_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Part of a weekly series. Edits apply to this session only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Repeat weekly',
            style: TextStyle(color: context.primaryText),
          ),
          subtitle: _repeatWeekly
              ? Text(
                  _repeatSummary,
                  style: TextStyle(color: context.secondaryText),
                )
              : null,
          value: _repeatWeekly,
          onChanged: (value) {
            setState(() {
              _repeatWeekly = value;
            });
          },
        ),
        if (_repeatWeekly) ...[
          const SizedBox(height: AppSpacing.sm),
          _FieldLabel('Repeat until'),
          _TapField(
            label: _formatDate(_repeatUntil),
            onTap: _pickRepeatUntil,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(
                  _isEditing ? 'Edit session' : 'Plan your next study block',
                ),
                leading: const BackButton(),
                actions: [
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: _saving ? null : _delete,
                    ),
                ],
              ),
              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(
                      AppSpacing.lg,
                    ),
                    children: [
                      if (_subjects.isEmpty)
                        Text(
                          'Add a subject first (Subjects tab) before planning a session.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        )
                      else ...[
                        _FieldLabel('Subject'),
                        DropdownButtonFormField<String>(
                          value: _subjectId,
                          decoration: _fieldDecoration(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          items: _subjects
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _subjectId = value;
                              _topicId = null;
                            });

                            _loadTopics(value);
                          },
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        _FieldLabel(
                          'Topic (optional)',
                        ),
                        DropdownButtonFormField<String?>(
                          value: _topicId,
                          decoration: _fieldDecoration(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._topics.map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _topicId = value;
                            });
                          },
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        _FieldLabel('Date'),
                        _TapField(
                          label: _formatDate(_date),
                          onTap: _pickDate,
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Start'),
                                  _TapField(
                                    label: _formatTime(
                                      _startTime,
                                    ),
                                    onTap: () => _pickTime(
                                      isStart: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: AppSpacing.md,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('End'),
                                  _TapField(
                                    label: _formatTime(
                                      _endTime,
                                    ),
                                    onTap: () => _pickTime(
                                      isStart: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        _buildRepeatSection(),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        _FieldLabel('Notes'),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: _fieldDecoration(
                            hint: 'Practice integration questions',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(
                            height: AppSpacing.md,
                          ),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                        const SizedBox(
                          height: AppSpacing.xl,
                        ),
                        PrimaryButton(
                          label: _saving ? 'Saving...' : 'Save Session',
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppRadii.control,
        ),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TapField({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppRadii.control,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppRadii.control,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
