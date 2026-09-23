import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

class EditProfileScreen extends StatefulWidget {
  final Student student;

  const EditProfileScreen({super.key, required this.student});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _programController;
  late final TextEditingController _levelController;
  final _repo = StudentRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _schoolController = TextEditingController(text: widget.student.school);
    _programController = TextEditingController(text: widget.student.program);
    _levelController = TextEditingController(text: widget.student.level);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _programController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final updated = widget.student.copyWith(
      name: _nameController.text.trim(),
      school: _schoolController.text.trim(),
      program: _programController.text.trim(),
      level: _levelController.text.trim(),
    );
    await _repo.update(updated);

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
              AppBar(title: const Text('Edit profile'), leading: const BackButton()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field('Name', _nameController),
                      const SizedBox(height: AppSpacing.lg),
                      _field('School', _schoolController),
                      const SizedBox(height: AppSpacing.lg),
                      _field('Program', _programController),
                      const SizedBox(height: AppSpacing.lg),
                      _field('Level', _levelController),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: PrimaryButton(
                  label: _saving ? 'Saving...' : 'Save',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}