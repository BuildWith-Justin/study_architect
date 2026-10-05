import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/daily_goal_dial.dart';

class GoalDialScreen extends StatefulWidget {
  final int initialMinutes;
  final ValueChanged<int> onContinue;

  const GoalDialScreen({
    super.key,
    this.initialMinutes = 180,
    required this.onContinue,
  });

  @override
  State<GoalDialScreen> createState() => _GoalDialScreenState();
}

class _GoalDialScreenState extends State<GoalDialScreen> {
  late int _minutes = widget.initialMinutes;

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
            "What's your daily study goal?",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'How much time would you like to study each day?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
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
                    Center(
                      child: DailyGoalDial(
                        minutes: _minutes,
                        onChanged: (m) => setState(() => _minutes = m),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Slider(
                      value: _minutes.clamp(15, 480).toDouble(),
                      min: 15,
                      max: 480,
                      divisions: 31,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _minutes = v.round()),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('15m', style: TextStyle(color: secondary)),
                          Text('8h', style: TextStyle(color: secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'You can change this later.',
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => widget.onContinue(_minutes),
          ),
        ],
      ),
    );
  }
}
