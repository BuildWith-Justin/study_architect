import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/task.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/app_buttons.dart';

class AddEditTaskScreen extends StatefulWidget {
  final Task? existing;

  const AddEditTaskScreen({super.key, this.existing});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _taskRepo = TaskRepository();
  final _subjectRepo = SubjectRepository();
  final _topicRepo = TopicRepository();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  List<Subject> _subjects = [];
  List<Topic> _topics = [];
  String? _subjectId;
  String? _topicId;
  TaskType _type = TaskType.assignment;
  late DateTime _dueDate;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController.text = existing?.title ?? '';
    _notesController.text = existing?.notes ?? '';
    _subjectId = existing?.subjectId;
    _topicId = existing?.topicId;
    _type = existing?.type ?? TaskType.assignment;
    _dueDate = existing?.dueDate ?? DateTime.now();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subjects = await _subjectRepo.getAll();
    setState(() {
      _subjects = subjects;
      _subjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
      _loading = false;
    });
    if (_subjectId != null) _loadTopics(_subjectId!);
  }

  Future<void> _loadTopics(String subjectId) async {
    final topics = await _topicRepo.getForSubject(subjectId);
    setState(() {
      _topics = topics;
      if (!_topics.any((t) => t.id == _topicId)) _topicId = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _subjectId == null) return;

    setState(() => _saving = true);

    final task = Task(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: title,
      subjectId: _subjectId!,
      topicId: _topicId,
      dueDate: _dueDate,
      type: _type,
      notes: _notesController.text.trim(),
      completed: widget.existing?.completed ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (_isEditing) {
      await _taskRepo.update(task);
    } else {
      await _taskRepo.create(task);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _taskRepo.delete(widget.existing!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(_isEditing ? 'Edit task' : 'New task'),
                leading: const BackButton(),
                actions: [
                  if (_isEditing)
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
                ],
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _FieldLabel('Title'),
                      TextField(
                        controller: _titleController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _fieldDecoration(hint: 'Complete 20 calculus questions'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_subjects.isEmpty)
                        Text(
                          'Add a subject first (Subjects tab) before creating a task.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        )
                      else ...[
                        _FieldLabel('Subject'),
                        DropdownButtonFormField<String>(
                          value: _subjectId,
                          decoration: _fieldDecoration(),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          items: _subjects
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _subjectId = value);
                            _loadTopics(value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel('Topic (optional)'),
                        DropdownButtonFormField<String?>(
                          value: _topicId,
                          decoration: _fieldDecoration(),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('None')),
                            ..._topics.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (value) => setState(() => _topicId = value),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel('Type'),
                      DropdownButtonFormField<TaskType>(
                        value: _type,
                        decoration: _fieldDecoration(),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        items: TaskType.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                            .toList(),
                        onChanged: (value) => setState(() => _type = value!),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel('Due date'),
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(AppRadii.control),
                          ),
                          child: Text(
                            '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel('Notes'),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _fieldDecoration(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: _saving ? 'Saving...' : 'Save Task',
                        onPressed: (_saving || _titleController.text.trim().isEmpty || _subjectId == null)
                            ? null
                            : _save,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(TaskType type) {
    switch (type) {
      case TaskType.assignment:
        return 'Assignment';
      case TaskType.reading:
        return 'Reading';
      case TaskType.revision:
        return 'Revision';
      case TaskType.project:
        return 'Project';
      case TaskType.other:
        return 'Other';
    }
  }

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide.none,
        ),
      );
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}