import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Dark splash shown while the app decides where to go.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBackgroundGradientTop,
              AppColors.surfaceDarkAlt,
              Color(0xFF3A2E4F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(size: 84),
              const SizedBox(height: AppSpacing.lg),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(text: 'Study '),
                    TextSpan(
                      text: 'Architect',
                      style: TextStyle(color: AppColors.teal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Plan  ·  Study  ·  Achieve',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const Spacer(flex: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: Text(
                  'Your personal study companion\nfor a better tomorrow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}