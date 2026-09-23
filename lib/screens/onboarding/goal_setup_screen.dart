import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

class GoalSetupScreen extends StatefulWidget {
  final void Function(int dailyGoalHours) onContinue;

  const GoalSetupScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  double _hours = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            "What's your daily study goal?",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose a target you can realistically maintain.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl * 2),
          Center(
            child: Text(
              '${_hours.round()}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Center(
            child: Text(
              'hours / day',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Slider(
            value: _hours,
            min: 1,
            max: 6,
            divisions: 5,
            activeColor: AppColors.accentPurpleStrong,
            onChanged: (value) {
              setState(() => _hours = value);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '1h',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '3h',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '6h',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => widget.onContinue(_hours.round()),
          ),
        ],
      ),
    );
  }
}
