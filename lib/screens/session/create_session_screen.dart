import 'package:flutter/material.dart';
import '../../core/data_refresh_bus.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/topic_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';
import '../timetable/add_edit_session_screen.dart';
import 'focus_timer_screen.dart';

/// V2 Step 8a: the screen behind the "+" nav item (route /plan).
///
/// Pick a subject, an optional topic and a focus length, then either:
///  - "Start focus now"  -> opens the Focus Timer straight away, or
///  - "Schedule for later" -> opens the Step 7b session form (unchanged).
class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  static const _lengthOptions = [25, 45, 60, 90, 120];

  final _subjectRepo = SubjectRepository();
  final _topicRepo = TopicRepository();

  List<Subject> _subjects = [];
  List<Topic> _topics = [];

  String? _subjectId;
  String? _topicId;
  int _minutes = 60;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Subject? get _selectedSubject {
    for (final s in _subjects) {
      if (s.id == _subjectId) return s;
    }
    return null;
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _subjectRepo.getAll();

      if (!mounted) return;

      setState(() {
        _subjects = subjects;
        _subjectId = subjects.isNotEmpty ? subjects.first.id : null;
        _loading = false;
        _error = null;
      });

      if (_subjectId != null) {
        await _loadTopics(_subjectId!);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load your subjects.';
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _topics = [];
        _topicId = null;
      });
    }
  }

  Future<void> _startNow() async {
    final subject = _selectedSubject;

    if (subject == null) {
      setState(() {
        _error = 'Choose a subject first.';
      });
      return;
    }

    String? topicName;
    for (final t in _topics) {
      if (t.id == _topicId) topicName = t.name;
    }

    final navigator = Navigator.of(context);

    // pushReplacement: closing the timer returns straight to the tab
    // the user came from, not back to this form.
    await navigator.pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => FocusTimerScreen(
          subjectId: subject.id,
          subjectName: subject.name,
          subjectColorValue: subject.colorValue,
          topicId: _topicId,
          topicName: topicName,
          goal: Duration(minutes: _minutes),
        ),
      ),
    );

    // Tell Home / Timetable that sessions may have changed.
    DataRefreshBus.instance.notify(RefreshScope.sessions);
  }

  void _scheduleLater() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => AddEditSessionScreen(initialDate: DateTime.now()),
      ),
    );
  }

  InputDecoration get _fieldDecoration => InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide.none,
        ),
      );

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.primaryText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _subjectDot(int colorValue) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _label('Subject'),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _subjectId,
          isExpanded: true,
          dropdownColor: AppColors.surfaceLight,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: _fieldDecoration,
          items: _subjects
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Row(
                    children: [
                      _subjectDot(s.colorValue),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _subjectId = value;
              _topicId = null;
              _topics = [];
              _error = null;
            });
            _loadTopics(value);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Topic (optional)'),
        DropdownButtonFormField<String?>(
          // ignore: deprecated_member_use
          value: _topicId,
          isExpanded: true,
          dropdownColor: AppColors.surfaceLight,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: _fieldDecoration,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No specific topic'),
            ),
            ..._topics.map(
              (t) => DropdownMenuItem<String?>(
                value: t.id,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _topicId = value;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Focus length'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _lengthOptions.map((m) {
            final selected = m == _minutes;
            return ChoiceChip(
              label: Text(formatDuration(m)),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceLight,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
              onSelected: (_) {
                setState(() {
                  _minutes = m;
                });
              },
            );
          }).toList(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Start focus now',
          icon: Icons.play_arrow_rounded,
          onPressed: _startNow,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Schedule for later instead',
          onPressed: _scheduleLater,
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: context.secondaryText,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? 'Add a subject first',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.primaryText,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error == null
                  ? 'Create a subject in the Subjects tab, then come back to plan a session.'
                  : 'Please go back and try again.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Plan a session'),
                leading: const BackButton(),
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _subjects.isEmpty
                        ? _buildEmpty()
                        : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
