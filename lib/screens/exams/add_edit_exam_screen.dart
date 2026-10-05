import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/data_refresh_bus.dart';
import '../../models/exam.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/exam_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/exam_format.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

/// Creates a new exam (no [existing]) or edits one. Pops with `true`
/// when something was saved.
///
/// When creating, every topic of the chosen subject starts ticked, so the
/// checklist is ready in one tap. The subject cannot be changed after the
/// exam exists, because the checklist is made of that subject's topics.
class AddEditExamScreen extends StatefulWidget {
  final Exam? existing;
  final String? initialSubjectId;

  const AddEditExamScreen({super.key, this.existing, this.initialSubjectId});

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Subject> _subjects = [];
  List<Topic> _topics = [];
  final Set<String> _selected = {};
  String? _subjectId;

  late DateTime _date;
  late TimeOfDay _time;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _subjectId != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _locationController.text = existing.location;
      _notesController.text = existing.notes;
      _date = DateTime(
        existing.examDate.year,
        existing.examDate.month,
        existing.examDate.day,
      );
      _time = TimeOfDay(
        hour: existing.examDate.hour,
        minute: existing.examDate.minute,
      );
    } else {
      final inTwoWeeks = DateTime.now().add(const Duration(days: 14));
      _date = DateTime(inTwoWeeks.year, inTwoWeeks.month, inTwoWeeks.day);
      _time = const TimeOfDay(hour: 9, minute: 0);
    }

    _init();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final subjects = await SubjectRepository().getAll();

      String? subjectId = widget.existing?.subjectId ?? widget.initialSubjectId;
      if (!_isEditing &&
          (subjectId == null || !subjects.any((s) => s.id == subjectId))) {
        subjectId = subjects.isEmpty ? null : subjects.first.id;
      }

      var topics = <Topic>[];
      var selected = <String>{};
      if (subjectId != null) {
        topics = await TopicRepository().getForSubject(subjectId);
        if (_isEditing) {
          final links =
              await ExamRepository().getTopicLinks(widget.existing!.id);
          selected = links.map((l) => l.topicId).toSet();
        } else {
          selected = topics.map((t) => t.id).toSet();
        }
      }

      if (!mounted) return;

      setState(() {
        _subjects = subjects;
        _subjectId = subjectId;
        _topics = topics;
        _selected
          ..clear()
          ..addAll(selected);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your subjects. Please go back and try again.';
      });
    }
  }

  Future<void> _pickSubject(String id) async {
    if (_isEditing || id == _subjectId) return;

    try {
      final topics = await TopicRepository().getForSubject(id);
      if (!mounted) return;
      setState(() {
        _subjectId = id;
        _topics = topics;
        _selected
          ..clear()
          ..addAll(topics.map((t) => t.id));
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load that subject\'s topics.');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = DateTime(now.year - 1);
    final end = DateTime(now.year + 3, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(base) ? DateTime(_date.year) : base,
      lastDate: _date.isAfter(end) ? DateTime(_date.year + 1, 12, 31) : end,
    );

    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);

    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ExamRepository();
      final examDate = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      // Keep roadmap order.
      final topicIds = _topics
          .where((t) => _selected.contains(t.id))
          .map((t) => t.id)
          .toList();

      final existing = widget.existing;
      if (existing != null) {
        await repo.update(
          existing.copyWith(
            title: _titleController.text.trim(),
            examDate: examDate,
            location: _locationController.text.trim(),
            notes: _notesController.text.trim(),
          ),
          topicIds: topicIds,
        );
      } else {
        await repo.create(
          Exam(
            id: const Uuid().v4(),
            subjectId: _subjectId!,
            title: _titleController.text.trim(),
            examDate: examDate,
            location: _locationController.text.trim(),
            notes: _notesController.text.trim(),
            createdAt: DateTime.now(),
          ),
          topicIds: topicIds,
        );
      }

      DataRefreshBus.instance.notify(RefreshScope.exams);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the exam. Please try again.';
      });
    }
  }

  // ------------------------------------------------------------ UI helpers

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.secondaryText,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  /// Form fields keep a fixed light surface with fixed dark text in both
  /// themes so typed text is always visible (same as the subject form).
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      counterText: '',
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Subject'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in _subjects)
                ChoiceChip(
                  label: Text(s.name),
                  selected: s.id == _subjectId,
                  selectedColor: AppColors.primarySoft,
                  labelStyle: TextStyle(
                    color: s.id == _subjectId
                        ? AppColors.primaryDark
                        : context.primaryText,
                  ),
                  onSelected: _isEditing ? null : (_) => _pickSubject(s.id),
                ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The subject cannot be changed after the exam is created.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.secondaryText,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailsCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Exam title'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: _fieldDecoration('Midterm'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Date and time'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _pickerField(
                  icon: Icons.calendar_today_rounded,
                  text: examDateLabel(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: _pickerField(
                  icon: Icons.access_time_rounded,
                  text: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Location (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _locationController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            style: const TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: _fieldDecoration('Room 4, Main Hall'),
          ),
          const SizedBox(height: AppSpacing.md),
          _label(context, 'Notes (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            style: const TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: _fieldDecoration('Bring a calculator'),
          ),
        ],
      ),
    );
  }

  Widget _topicsCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label(context, 'Topics to prepare')),
              if (_topics.isNotEmpty) ...[
                TextButton(
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(_topics.map((t) => t.id));
                  }),
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          if (_topics.isEmpty)
            Text(
              'This subject has no topics yet. Add topics from the subject '
              'page, then edit this exam to include them.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.secondaryText,
                  ),
            )
          else
            for (final t in _topics)
              CheckboxListTile(
                value: _selected.contains(t.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(t.id);
                    } else {
                      _selected.remove(t.id);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: Text(
                  t.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.primaryText,
                      ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _noSubjects(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: context.secondaryText,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add a subject first',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'An exam belongs to a subject. Create one in the Subjects tab, '
              'then come back.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_subjects.isEmpty) {
      body = _noSubjects(context);
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _subjectCard(context),
                    const SizedBox(height: AppSpacing.lg),
                    _detailsCard(context),
                    const SizedBox(height: AppSpacing.lg),
                    _topicsCard(context),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: _isEditing ? 'Save changes' : 'Save exam',
              loading: _saving,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(_isEditing ? 'Edit exam' : 'Add exam'),
                leading: const BackButton(),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
