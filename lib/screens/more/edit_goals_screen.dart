import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

class EditGoalsScreen extends StatefulWidget {
  final Student student;

  const EditGoalsScreen({super.key, required this.student});

  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
  final _repo = StudentRepository();
  late double _dailyHours;
  late double _weeklyHours;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dailyHours = (widget.student.dailyGoalMinutes / 60).toDouble();
    _weeklyHours = (widget.student.weeklyGoalMinutes / 60).toDouble();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.student.copyWith(
      dailyGoalMinutes: _dailyHours.round() * 60,
      weeklyGoalMinutes: _weeklyHours.round() * 60,
    );
    await _repo.update(updated);

    // The daily reminder's message doesn't depend on the goal value
    // itself, but re-scheduling here keeps the reminder time fresh
    // if that's ever made user-configurable later.
    await NotificationService.instance.scheduleDailyGoalReminder(
      const TimeOfDay(hour: 19, minute: 0),
    );

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
              AppBar(title: const Text('Study goals'), leading: const BackButton()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Daily goal: ${_dailyHours.round()} hours',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Slider(
                        value: _dailyHours.clamp(1, 12),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        activeColor: AppColors.accentPurpleStrong,
                        onChanged: (v) => setState(() => _dailyHours = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Weekly goal: ${_weeklyHours.round()} hours',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Slider(
                        value: _weeklyHours.clamp(1, 60),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        activeColor: AppColors.accentBlueStrong,
                        onChanged: (v) => setState(() => _weeklyHours = v),
                      ),
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
}