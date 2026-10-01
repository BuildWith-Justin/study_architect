import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_logo.dart';

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
    final secondary = AppColors.secondaryText(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppLogo(size: 72)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Study Architect',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Plan  ·  Study  ·  Achieve',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Your personal study companion\nfor a better tomorrow.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillLabel(label: 'PLAN', hue: AppColors.accentPurpleStrong),
              SizedBox(width: AppSpacing.sm),
              _PillLabel(label: 'STUDY', hue: AppColors.accentBlueStrong),
              SizedBox(width: AppSpacing.sm),
              _PillLabel(label: 'ACHIEVE', hue: AppColors.accentGreenStrong),
            ],
          ),
          const SizedBox(height: AppSpacing.xl * 2),
          PrimaryButton(label: 'Get Started', onPressed: onGetStarted),
          const SizedBox(height: AppSpacing.sm),
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
        color: hue.withValues(alpha: 0.15),
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