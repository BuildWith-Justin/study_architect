import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/daily_goal_dial.dart';
import '../../widgets/gradient_background.dart';

class EditGoalsScreen extends StatefulWidget {
  final Student student;

  const EditGoalsScreen({super.key, required this.student});

  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
  static const _weeklyMin = 60;
  static const _weeklyMax = 3600;
  static const _weeklyStep = 30;

  final _repo = StudentRepository();

  late final int _initialDaily;
  late final int _initialWeekly;
  late int _daily;
  late int _weekly;
  bool _saving = false;
  bool _allowLeave = false;

  @override
  void initState() {
    super.initState();
    _initialDaily = _snapDaily(widget.student.dailyGoalMinutes);
    _initialWeekly = _snapWeekly(widget.student.weeklyGoalMinutes);
    _daily = _initialDaily;
    _weekly = _initialWeekly;
  }

  // Goals keep their exact minutes (no more rounding to whole hours).
  int _snapDaily(int minutes) {
    final snapped =
        ((minutes / DailyGoalDial.step).round()) * DailyGoalDial.step;
    if (snapped < DailyGoalDial.minMinutes) return DailyGoalDial.minMinutes;
    if (snapped > DailyGoalDial.maxMinutes) return DailyGoalDial.maxMinutes;
    return snapped;
  }

  int _snapWeekly(int minutes) {
    final snapped = ((minutes / _weeklyStep).round()) * _weeklyStep;
    if (snapped < _weeklyMin) return _weeklyMin;
    if (snapped > _weeklyMax) return _weeklyMax;
    return snapped;
  }

  bool get _dirty => _daily != _initialDaily || _weekly != _initialWeekly;
  bool get _weeklyTooLow => _weekly < _daily;
  bool get _canSave => _dirty && !_weeklyTooLow && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final updated = widget.student.copyWith(
        dailyGoalMinutes: _daily,
        weeklyGoalMinutes: _weekly,
      );
      await _repo.update(updated);

      // Every screen that shows the goals reloads right away.
      DataRefreshBus.instance.notify(RefreshScope.all);

      // The daily reminder text shows the goal, so refresh it too.
      await NotificationService.instance.applyAllSafe();

      if (!mounted) return;
      setState(() => _allowLeave = true);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your goals. Try again.')),
      );
    }
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your new goals have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.secondaryText(context);

    return PopScope(
      canPop: !_dirty || _allowLeave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave == true && mounted) {
          setState(() => _allowLeave = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Study goals'),
                  leading: const BackButton(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                            horizontal: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(AppRadii.outer),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Daily goal',
                                style: TextStyle(
                                  color: context.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              DailyGoalDial(
                                minutes: _daily,
                                size: 220,
                                onChanged: (m) => setState(() => _daily = m),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(AppRadii.outer),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly goal',
                                style: TextStyle(
                                  color: context.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                DailyGoalDial.format(_weekly),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Slider(
                                value: _weekly.toDouble(),
                                min: _weeklyMin.toDouble(),
                                max: _weeklyMax.toDouble(),
                                divisions:
                                    (_weeklyMax - _weeklyMin) ~/ _weeklyStep,
                                activeColor: AppColors.primary,
                                onChanged: (v) => setState(
                                  () => _weekly = _snapWeekly(v.round()),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    label: const Text('Daily x 5'),
                                    onPressed: () => setState(
                                      () => _weekly = _snapWeekly(_daily * 5),
                                    ),
                                  ),
                                  ActionChip(
                                    label: const Text('Daily x 7'),
                                    onPressed: () => setState(
                                      () => _weekly = _snapWeekly(_daily * 7),
                                    ),
                                  ),
                                ],
                              ),
                              if (_weeklyTooLow) ...[
                                const SizedBox(height: AppSpacing.md),
                                const Text(
                                  'Your weekly goal is smaller than your '
                                  'daily goal. Raise it to save.',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Goals count from today. Past days keep the goal '
                          'they were reached with.',
                          style: TextStyle(color: secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save',
                    onPressed: _canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
