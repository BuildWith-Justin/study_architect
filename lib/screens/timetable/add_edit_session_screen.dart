import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/app_buttons.dart';

/// Handles both creating a session (pass no [existing]) and editing
/// one. [initialDate] pre-selects a date for new sessions (e.g. the
/// day currently selected on the Timetable screen). Pops `true` on
/// save/delete so the caller knows to reload.
class AddEditSessionScreen extends StatefulWidget {
  final StudySession? existing;
  final DateTime? initialDate;

  const AddEditSessionScreen({
    super.key,
    this.existing,
    this.initialDate,
  });

  @override
  State<AddEditSessionScreen> createState() =>
      _AddEditSessionScreenState();
}

class _AddEditSessionScreenState
    extends State<AddEditSessionScreen> {
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

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _date =
        existing?.scheduledDate ??
        widget.initialDate ??
        DateTime.now();

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
        _subjectId ??=
            subjects.isNotEmpty ? subjects.first.id : null;
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
      final topics =
          await _topicRepo.getForSubject(subjectId);

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate:
          DateTime.now().subtract(const Duration(days: 365)),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _date = picked;
    });
  }

  Future<void> _pickTime({
    required bool isStart,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart ? _startTime : _endTime,
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

    final session = StudySession(
      id: widget.existing?.id ?? const Uuid().v4(),
      subjectId: _subjectId!,
      topicId: _topicId,
      scheduledDate: startOfDay(_date),
      startTime: start,
      endTime: end,
      notes: _notesController.text.trim(),
      status:
          widget.existing?.status ??
          SessionStatus.planned,
      complete:
          widget.existing?.complete ?? false,
      actualDuration:
          widget.existing?.actualDuration,
      rating: widget.existing?.rating,
    );

    if (!session.isTimeRangeValid) {
      setState(() {
        _error =
            'End time must be after start time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _sessionRepo.update(session);
      } else {
        await _sessionRepo.create(session);
      }

      final subject = _subjects.firstWhere(
        (s) => s.id == session.subjectId,
        orElse: () => _subjects.first,
      );

      await NotificationService.instance
          .scheduleSessionReminder(
        sessionId: session.id,
        subjectName: subject.name,
        sessionStart: session.startTime,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error =
            'Could not save the session. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text(
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
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

    if (confirmed != true) return;

    try {
      await _sessionRepo.delete(
        widget.existing!.id,
      );

      await NotificationService.instance
          .cancelSessionReminder(
        widget.existing!.id,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not delete the session. Please try again.';
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return time.format(context);
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
                  _isEditing
                      ? 'Edit session'
                      : 'Plan your next study block',
                ),
                leading: const BackButton(),
                actions: [
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed:
                          _saving ? null : _delete,
                    ),
                ],
              ),
              if (_loading)
                const Expanded(
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.all(
                      AppSpacing.lg,
                    ),
                    children: [
                      if (_subjects.isEmpty)
                        Text(
                          'Add a subject first (Subjects tab) before planning a session.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    AppColors.textSecondary,
                              ),
                        )
                      else ...[
                        _FieldLabel('Subject'),
                        DropdownButtonFormField<String>(
                          value: _subjectId,
                          decoration:
                              _fieldDecoration(),
                          style: const TextStyle(
                            color:
                                AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          items: _subjects
                              .map(
                                (s) =>
                                    DropdownMenuItem(
                                  value: s.id,
                                  child:
                                      Text(s.name),
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
                          decoration:
                              _fieldDecoration(),
                          style: const TextStyle(
                            color:
                                AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._topics.map(
                              (t) =>
                                  DropdownMenuItem(
                                value: t.id,
                                child:
                                    Text(t.name),
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
                          label:
                              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                          onTap: _pickDate,
                        ),
                        const SizedBox(
                          height: AppSpacing.lg,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Start'),
                                  _TapField(
                                    label:
                                        _formatTime(
                                      _startTime,
                                    ),
                                    onTap: () =>
                                        _pickTime(
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('End'),
                                  _TapField(
                                    label:
                                        _formatTime(
                                      _endTime,
                                    ),
                                    onTap: () =>
                                        _pickTime(
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
                        _FieldLabel('Notes'),
                        TextField(
                          controller:
                              _notesController,
                          maxLines: 3,
                          style: const TextStyle(
                            color:
                                AppColors.textPrimary,
                          ),
                          decoration:
                              _fieldDecoration(
                            hint:
                                'Practice integration questions',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(
                            height: AppSpacing.md,
                          ),
                          Text(
                            _error!,
                            style:
                                const TextStyle(
                              color:
                                  Colors.redAccent,
                            ),
                          ),
                        ],
                        const SizedBox(
                          height: AppSpacing.xl,
                        ),
                        PrimaryButton(
                          label: _saving
                              ? 'Saving...'
                              : 'Save Session',
                          onPressed: _saving
                              ? null
                              : _save,
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
        borderRadius:
            BorderRadius.circular(
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
      padding:
          const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(
              color:
                  AppColors.textSecondary,
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
      borderRadius:
          BorderRadius.circular(
        AppRadii.control,
      ),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius:
              BorderRadius.circular(
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