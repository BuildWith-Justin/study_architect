import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

class ProfileSetupScreen extends StatefulWidget {
  final void Function(
    String name,
    String school,
    String program,
    String level,
  ) onContinue;

  const ProfileSetupScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _levels = [
    'Level 100',
    'Level 200',
    'Level 300',
    'Level 400',
    'Postgraduate',
    'Other',
  ];

  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _programController = TextEditingController();
  String _level = '';

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  String get _initials {
    final parts = _nameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _programController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_canContinue) return;

    FocusScope.of(context).unfocus();

    widget.onContinue(
      _nameController.text.trim(),
      _schoolController.text.trim(),
      _programController.text.trim(),
      _level,
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.secondaryText(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Let's set up your profile",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tell us a bit about yourself so we can personalise '
            'your study experience.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _nameController,
                      builder: (context, _) {
                        final initials = _initials;
                        return Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.teal, AppColors.primary],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: initials.isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 40,
                                )
                              : Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _LabeledField(
                    label: 'Name *',
                    controller: _nameController,
                    hint: 'Paul',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'School (optional)',
                    controller: _schoolController,
                    hint: 'Ghana Communication Technology University',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'Program (optional)',
                    controller: _programController,
                    hint: 'Computer Engineering',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Level (optional)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _level.isEmpty ? null : _level,
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
                    hint: const Text(
                      'Level 300',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    decoration: _fieldDecoration(null),
                    items: [
                      for (final l in _levels)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? ''),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedBuilder(
            animation: _nameController,
            builder: (context, _) {
              return PrimaryButton(
                label: 'Continue',
                onPressed: _canContinue ? _continue : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

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

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText(context),
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          cursorColor: AppColors.primary,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _fieldDecoration(hint),
        ),
      ],
    );
  }
}
