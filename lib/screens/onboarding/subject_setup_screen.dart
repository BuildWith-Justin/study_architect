import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

class SubjectSetupScreen extends StatefulWidget {
  final void Function(
    String name,
    SubjectDifficulty difficulty,
    int weeklyTargetHours,
    int colorValue,
  ) onSave;

  const SubjectSetupScreen({
    super.key,
    required this.onSave,
  });

  @override
  State<SubjectSetupScreen> createState() => _SubjectSetupScreenState();
}

class _SubjectSetupScreenState extends State<SubjectSetupScreen> {
  final _nameController = TextEditingController();

  SubjectDifficulty _difficulty = SubjectDifficulty.medium;
  double _weeklyTargetHours = 6;
  Color _color = AppColors.accentPurpleStrong;

  static const _colorOptions = [
    AppColors.accentPurpleStrong,
    AppColors.accentBlueStrong,
    AppColors.accentGreenStrong,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Add your subjects',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with the subjects you study most.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'Subject Name',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            cursorColor: AppColors.accentPurpleStrong,
            decoration: InputDecoration(
              hintText: 'Mathematics',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadii.control,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Difficulty',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Slider(
            value: _weeklyTargetHours,
            min: 1,
            max: 20,
            divisions: 19,
            activeColor: AppColors.accentPurpleStrong,
            onChanged: (value) {
              setState(() {
                _weeklyTargetHours = value;
              });
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Color',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

          const SizedBox(height: AppSpacing.xl * 2),

          PrimaryButton(
            label: 'Save Subject',
            onPressed: _canSave
                ? () {
                    widget.onSave(
                      _nameController.text.trim(),
                      _difficulty,
                      _weeklyTargetHours.round(),
                      _color.toARGB32(),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}