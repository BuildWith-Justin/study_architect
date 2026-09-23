import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onImportExisting;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onImportExisting,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'STUDY ARCHITECT',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 2,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Plan your study life.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Study with intention. Track your progress.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillLabel(label: 'PLAN', hue: AppColors.accentPurpleStrong),
              const SizedBox(width: AppSpacing.sm),
              _PillLabel(label: 'STUDY', hue: AppColors.accentBlueStrong),
              const SizedBox(width: AppSpacing.sm),
              _PillLabel(label: 'TRACK', hue: AppColors.accentGreenStrong),
            ],
          ),
          const SizedBox(height: AppSpacing.xl * 2),
          PrimaryButton(label: 'Get Started', onPressed: onGetStarted),
          SecondaryButton(
            label: 'I already have my data',
            onPressed: onImportExisting,
          ),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  final String label;
  final Color hue;

  const _PillLabel({required this.label, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: hue,
          letterSpacing: 1,
        ),
      ),
    );
  }
}