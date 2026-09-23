import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/subject.dart';
import '../../repositories/subject_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

/// Handles both creating a new subject (pass no [existing]) and
/// editing one (pass the current Subject). Pops with `true` when a
/// save happened, so the caller knows to reload its list.
class AddEditSubjectScreen extends StatefulWidget {
  final Subject? existing;

  const AddEditSubjectScreen({super.key, this.existing});

  @override
  State<AddEditSubjectScreen> createState() => _AddEditSubjectScreenState();
}

class _AddEditSubjectScreenState extends State<AddEditSubjectScreen> {
  late final TextEditingController _nameController;
  late SubjectDifficulty _difficulty;
  late double _weeklyTargetHours;
  late Color _color;

  bool _saving = false;
  String? _error;

  static const _colorOptions = [
    AppColors.accentPurpleStrong,
    AppColors.accentBlueStrong,
    AppColors.accentGreenStrong,
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    _difficulty =
        existing?.difficulty ?? SubjectDifficulty.medium;

    _weeklyTargetHours =
        ((existing?.weeklyTargetMinutes ?? 360) / 60).toDouble();

    _color = existing != null
        ? Color(existing.colorValue)
        : AppColors.accentPurpleStrong;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

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
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save the subject. Please try again.';
      });
    }
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
                  _isEditing ? 'Edit subject' : 'Add subject',
                ),
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
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Subject Name',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _nameController,
                                onChanged: (_) {
                                  setState(() {
                                    _error = null;
                                  });
                                },
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                cursorColor:
                                    AppColors.accentPurpleStrong,
                                decoration: InputDecoration(
                                  hintText: 'Mathematics',
                                  hintStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Difficulty',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<SubjectDifficulty>(
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
                              Text(
                                'Weekly Target: ${_weeklyTargetHours.round()} hours',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              Slider(
                                value: _weeklyTargetHours.clamp(1, 20),
                                min: 1,
                                max: 20,
                                divisions: 19,
                                activeColor:
                                    AppColors.accentPurpleStrong,
                                onChanged: (value) {
                                  setState(() {
                                    _weeklyTargetHours = value;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Color',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: _colorOptions.map((color) {
                                  final selected =
                                      color.toARGB32() == _color.toARGB32();

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.sm,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _color = color;
                                        });
                                      },
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: color,
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.redAccent,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: _saving
                            ? 'Saving...'
                            : 'Save Subject',
                        onPressed: _saving ||
                                _nameController.text.trim().isEmpty
                            ? null
                            : _save,
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