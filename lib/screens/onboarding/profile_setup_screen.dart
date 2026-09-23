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
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _programController = TextEditingController();
  final _levelController = TextEditingController();

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _schoolController.text.trim().isNotEmpty &&
      _programController.text.trim().isNotEmpty &&
      _levelController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _programController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_canContinue) return;

    FocusScope.of(context).unfocus();

    widget.onContinue(
      _nameController.text.trim(),
      _schoolController.text.trim(),
      _programController.text.trim(),
      _levelController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            "Let's set up your study space.",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledField(
                    label: "What's your name?",
                    controller: _nameController,
                    hint: 'Paul',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'School',
                    controller: _schoolController,
                    hint: 'Ghana Communication Technology University',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'Program',
                    controller: _programController,
                    hint: 'Computer Engineering',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'Level',
                    controller: _levelController,
                    hint: '300',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedBuilder(
            animation: Listenable.merge([
              _nameController,
              _schoolController,
              _programController,
              _levelController,
            ]),
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
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
      ],
    );
  }
}