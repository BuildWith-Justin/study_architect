import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/subject.dart';
import '../../models/topic.dart';
import '../../repositories/subject_repository.dart';
import '../../core/data_refresh_bus.dart';
import '../../repositories/topic_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

/// Handles both creating a new subject (pass no [existing]) and
/// editing one (pass the current Subject). Pops with `true` when a
/// save happened, so the caller knows to reload its list.
///
/// When creating, the person can also list the subject's first topics.
/// They are saved in the order listed, which is the start of the
/// study roadmap. When editing, topics are managed from the subject's
/// detail screen instead.
class AddEditSubjectScreen extends StatefulWidget {
  final Subject? existing;

  const AddEditSubjectScreen({super.key, this.existing});

  @override
  State<AddEditSubjectScreen> createState() => _AddEditSubjectScreenState();
}

class _AddEditSubjectScreenState extends State<AddEditSubjectScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _topicController = TextEditingController();
  final List<String> _topics = [];

  late SubjectDifficulty _difficulty;
  late double _weeklyTargetHours;
  late Color _color;

  bool _saving = false;
  String? _error;

  // Same 6 colours as the first-time setup (onboarding) screen.
  static const _paletteColors = <Color>[
    Color(0xFF4C8DF6), // blue
    Color(0xFF1FB57F), // green
    Color(0xFFF59E0B), // orange
    Color(0xFFEC4899), // pink
    Color(0xFFEF4444), // red
    Color(0xFFA78BFA), // lavender
  ];

  // The palette, plus this subject's current colour when it is an older
  // colour no longer in the palette (so it stays selectable).
  late final List<Color> _colorOptions;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    _difficulty = existing?.difficulty ?? SubjectDifficulty.medium;

    _weeklyTargetHours =
        ((existing?.weeklyTargetMinutes ?? 360) / 60).toDouble();

    _color =
        existing != null ? Color(existing.colorValue) : _paletteColors.first;

    _colorOptions = [..._paletteColors];
    if (!_colorOptions.any((c) => c.toARGB32() == _color.toARGB32())) {
      _colorOptions.insert(0, _color);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _addTopicToList() {
    final value = _topicController.text.trim();
    if (value.isEmpty) return;

    final exists = _topics.any((t) => t.toLowerCase() == value.toLowerCase());

    setState(() {
      if (!exists) _topics.add(value);
      _topicController.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _saving) return;

    FocusScope.of(context).unfocus();

    // A topic typed but not yet added with "+" still counts.
    final pendingTopic = _topicController.text.trim();
    if (!_isEditing && pendingTopic.isNotEmpty) {
      final exists =
          _topics.any((t) => t.toLowerCase() == pendingTopic.toLowerCase());
      if (!exists) _topics.add(pendingTopic);
      _topicController.clear();
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    var topicsFailed = false;

    try {
      final repo = SubjectRepository();

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: name,
          difficulty: _difficulty,
          colorValue: _color.toARGB32(),
          weeklyTargetMinutes: _weeklyTargetHours.round() * 60,
        );

        await repo.update(updated);
      } else {
        final subject = Subject(
          id: const Uuid().v4(),
          name: name,
          difficulty: _difficulty,
          colorValue: _color.toARGB32(),
          weeklyTargetMinutes: _weeklyTargetHours.round() * 60,
          createdAt: DateTime.now(),
        );

        await repo.create(subject);

        // Topics are created one by one, in the order listed; the
        // repository appends each one at the end of the roadmap.
        // If this part fails the subject already exists, so we do not
        // report a failure (a retry would create a duplicate subject).
        try {
          final topicRepo = TopicRepository();
          for (final topicName in _topics) {
            await topicRepo.create(
              Topic(
                id: const Uuid().v4(),
                subjectId: subject.id,
                name: topicName,
              ),
            );
          }
        } catch (_) {
          topicsFailed = true;
        }
      }

      if (!mounted) return;

      if (topicsFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Subject saved, but some topics could not be added. '
              'You can add them from the subject page.',
            ),
          ),
        );
      }

      DataRefreshBus.instance.notify(RefreshScope.subjects);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save the subject. Please try again.';
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

  /// Form fields keep a fixed light surface with fixed dark text in
  /// both themes (see theme_helpers.dart) so typed text is always visible.
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

  Widget _topicsCard(BuildContext context) {
    if (_isEditing) {
      return _card(
        context,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: context.secondaryText,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Topics and their order are managed from the subject's roadmap.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Topics (optional)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  onSubmitted: (_) => _addTopicToList(),
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primary,
                  decoration: _fieldDecoration('e.g. Differential Equations'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: _addTopicToList,
                tooltip: 'Add topic',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_topics.isEmpty)
            Text(
              'Add topics in the order you plan to study them. '
              'You can reorder them later in the roadmap.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.secondaryText,
                  ),
            )
          else
            for (var i = 0; i < _topics.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _color,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _topics[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.primaryText,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: context.secondaryText,
                      tooltip: 'Remove topic',
                      onPressed: () {
                        setState(() {
                          _topics.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(_isEditing ? 'Edit subject' : 'Add subject'),
                leading: const BackButton(),
              ),
              Expanded(
                child: Padding(
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
                              _card(
                                context,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label(context, 'Subject name'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _nameController,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      maxLength: 40,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      cursorColor: AppColors.primary,
                                      decoration:
                                          _fieldDecoration('Mathematics'),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    _label(context, 'Difficulty'),
                                    const SizedBox(height: AppSpacing.sm),
                                    SegmentedButton<SubjectDifficulty>(
                                      showSelectedIcon: false,
                                      style: SegmentedButton.styleFrom(
                                        foregroundColor: context.primaryText,
                                        selectedForegroundColor:
                                            AppColors.primaryDark,
                                        selectedBackgroundColor:
                                            AppColors.primarySoft,
                                        side: BorderSide(
                                          color: context.secondaryText
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      segments: const [
                                        ButtonSegment(
                                          value: SubjectDifficulty.easy,
                                          label: Text('Easy'),
                                        ),
                                        ButtonSegment(
                                          value: SubjectDifficulty.medium,
                                          label: Text('Medium'),
                                        ),
                                        ButtonSegment(
                                          value: SubjectDifficulty.hard,
                                          label: Text('Hard'),
                                        ),
                                      ],
                                      selected: {_difficulty},
                                      onSelectionChanged: (selection) {
                                        setState(() {
                                          _difficulty = selection.first;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _label(context, 'Weekly target'),
                                        Text(
                                          '${_weeklyTargetHours.round()} h / week',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: _weeklyTargetHours.clamp(1, 20),
                                      min: 1,
                                      max: 20,
                                      divisions: 19,
                                      activeColor: AppColors.primary,
                                      inactiveColor: AppColors.primary
                                          .withValues(alpha: 0.2),
                                      onChanged: (value) {
                                        setState(() {
                                          _weeklyTargetHours = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _label(context, 'Color'),
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(
                                      spacing: AppSpacing.md,
                                      runSpacing: AppSpacing.sm,
                                      children: _colorOptions.map((color) {
                                        final selected = color.toARGB32() ==
                                            _color.toARGB32();

                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _color = color;
                                            });
                                          },
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: selected
                                                  ? Border.all(
                                                      color:
                                                          context.primaryText,
                                                      width: 2.5,
                                                    )
                                                  : null,
                                            ),
                                            child: selected
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _topicsCard(context),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.danger),
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
                        label: _isEditing ? 'Save changes' : 'Save subject',
                        loading: _saving,
                        onPressed:
                            _nameController.text.trim().isEmpty ? null : _save,
                      ),
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
