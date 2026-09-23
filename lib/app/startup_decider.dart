import 'package:flutter/material.dart';

import '../repositories/student_repository.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';
import '../widgets/main_scaffold.dart';

/// The app's actual root widget.
///
/// Checks whether a Student profile already exists in local storage.
/// If no profile exists, onboarding is shown.
/// If a profile exists, the main tab shell is shown.
class StartupDecider extends StatefulWidget {
  const StartupDecider({super.key});

  @override
  State<StartupDecider> createState() => _StartupDeciderState();
}

class _StartupDeciderState extends State<StartupDecider> {
  final _studentRepository = StudentRepository();

  bool? _onboardingComplete;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    if (!mounted) return;

    setState(() {
      _onboardingComplete = null;
      _error = null;
    });

    try {
      final student = await _studentRepository.getCurrent();

      if (!mounted) return;

      setState(() {
        _onboardingComplete = student != null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'StartupDecider failed to load student: $e\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _error = e;
      });
    }
  }

  Future<void> _handleOnboardingComplete() async {
    await _checkOnboardingStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not start Study Architect.',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'We could not load your local profile. '
                      'Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _checkOnboardingStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_onboardingComplete == null) {
      return const GradientBackground(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_onboardingComplete == false) {
      return OnboardingFlow(
        onComplete: _handleOnboardingComplete,
      );
    }

    return const MainScaffold();
  }
}