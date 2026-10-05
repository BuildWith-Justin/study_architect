import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

/// A subject the user added during onboarding, not yet saved.
class SubjectDraft {
  final String id;
  final String name;
  final SubjectDifficulty difficulty;
  final int weeklyTargetHours;
  final int colorValue;

  const SubjectDraft({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.weeklyTargetHours,
    required this.colorValue,
  });
}

const _subjectPalette = <Color>[
  Color(0xFF4C8DF6), // blue
  Color(0xFF1FB57F), // green
  Color(0xFFF59E0B), // orange
  Color(0xFFEC4899), // pink
  Color(0xFFEF4444), // red
  Color(0xFFA78BFA), // lavender
];

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

InputDecoration _fieldDecoration(String? hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surfaceLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide.none,
    ),
  );
}

class SubjectsSetupScreen extends StatefulWidget {
  final ValueChanged<List<SubjectDraft>> onFinish;

  const SubjectsSetupScreen({super.key, required this.onFinish});

  @override
  State<SubjectsSetupScreen> createState() => _SubjectsSetupScreenState();
}

class _SubjectsSetupScreenState extends State<SubjectsSetupScreen> {
  final _uuid = const Uuid();
  final List<SubjectDraft> _drafts = [];

  Future<void> _openAddSheet() async {
    FocusScope.of(context).unfocus();

    final draft = await showModalBottomSheet<SubjectDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSubjectSheet(
        takenNames: _drafts.map((d) => d.name.toLowerCase()).toSet(),
        initialColor: _subjectPalette[_drafts.length % _subjectPalette.length],
        newId: _uuid.v4(),
      ),
    );

    if (draft != null && mounted) {
      setState(() => _drafts.add(draft));
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.secondaryText(context);
    final primaryText = AppColors.primaryText(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your Subjects',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add the subjects you want to study.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView(
              children: [
                for (final d in _drafts)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color(d.colorValue).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: Color(d.colorValue),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_cap(d.difficulty.name)} · '
                                '${d.weeklyTargetHours}h / week',
                                style: TextStyle(
                                  color: secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: secondary),
                          onPressed: () => setState(() => _drafts.remove(d)),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _openAddSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Subject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                  ),
                ),
                if (_drafts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Text(
                      'Add at least one subject to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Continue',
            onPressed: _drafts.isEmpty
                ? null
                : () =>
                    widget.onFinish(List<SubjectDraft>.unmodifiable(_drafts)),
          ),
        ],
      ),
    );
  }
}

class _AddSubjectSheet extends StatefulWidget {
  final Set<String> takenNames;
  final Color initialColor;
  final String newId;

  const _AddSubjectSheet({
    required this.takenNames,
    required this.initialColor,
    required this.newId,
  });

  @override
  State<_AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends State<_AddSubjectSheet> {
  final _name = TextEditingController();
  SubjectDifficulty _difficulty = SubjectDifficulty.medium;
  int _hours = 6;
  late Color _color = widget.initialColor;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = '"$name" is already added.');
      return;
    }

    Navigator.pop(
      context,
      SubjectDraft(
        id: widget.newId,
        name: name,
        difficulty: _difficulty,
        weeklyTargetHours: _hours,
        colorValue: _color.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.secondaryText(context);
    final primaryText = AppColors.primaryText(context);
    final chipOff = AppColors.isDark(context)
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: secondary);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.outer),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Subject',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Subject Name *', style: labelStyle),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                cursorColor: AppColors.primary,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                decoration: _fieldDecoration('Mathematics'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('Difficulty', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final d in SubjectDifficulty.values)
                    ChoiceChip(
                      label: Text(_cap(d.name)),
                      selected: _difficulty == d,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: chipOff,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _difficulty == d ? Colors.white : primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Weekly Target', style: labelStyle),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _hours,
                isExpanded: true,
                dropdownColor: AppColors.surfaceLightAlt,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
                decoration: _fieldDecoration(null),
                items: [
                  for (var h = 1; h <= 20; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text('$h ${h == 1 ? 'hour' : 'hours'}'),
                    ),
                ],
                onChanged: (v) => setState(() => _hours = v ?? _hours),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Color', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in _subjectPalette)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: c,
                          child: c.toARGB32() == _color.toARGB32()
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save Subject',
                onPressed: _name.text.trim().isNotEmpty ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
