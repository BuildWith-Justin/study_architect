import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_service.dart';
import '../repositories/student_repository.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';
import '../widgets/gradient_background.dart';
import '../widgets/splash_view.dart';
import '../widgets/main_scaffold.dart';

/// Result of looking for the person's profile in the cloud.
enum _CloudCheck { restored, noProfile, unreachable }

/// The app's actual root widget.
///
/// Checks whether a Student profile already exists in local storage.
/// If no profile exists, onboarding is shown.
/// If a profile exists, the main tab shell is shown.
///
/// V2: if the local database is empty but the user is signed in, the
/// profile may already be in the cloud (new phone, reinstall, cleared
/// data). The cloud is asked directly:
/// - active profile found -> it is pulled (with retries) before the app opens
/// - no active profile    -> a genuinely new user, onboarding is shown
///   (a profile that was deleted is kept in the cloud with a deletedAt
///   date and is NOT restored)
/// - cloud unreachable    -> a "could not reach your account" screen, so a
///   bad network never sends a returning user into profile building
///   (which would create a second profile).
class StartupDecider extends StatefulWidget {
  const StartupDecider({super.key});

  @override
  State<StartupDecider> createState() => _StartupDeciderState();
}

class _StartupDeciderState extends State<StartupDecider> {
  final _studentRepository = StudentRepository();

  bool? _onboardingComplete;
  bool _cloudCheckFailed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  bool get _signedIn =>
      AuthService.isAvailable &&
      Supabase.instance.client.auth.currentUser != null;

  /// Asks the cloud whether this account already has an ACTIVE profile
  /// and, if so, pulls it onto this phone.
  Future<_CloudCheck> _restoreFromCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return _CloudCheck.unreachable;

    try {
      final rows = await client
          .from('students')
          .select('id, deletedAt')
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 10));
      final active = rows.where((r) => r['deletedAt'] == null).length;
      debugPrint(
        'StartupDecider: cloud profiles total=${rows.length} active=$active',
      );
      if (active == 0) return _CloudCheck.noProfile;
    } catch (e) {
      debugPrint('StartupDecider cloud check failed: $e');
      return _CloudCheck.unreachable;
    }

    // The cloud has an active profile: pull it. syncNow() never throws and
    // returns at once if another sync is already running, so keep
    // checking the local database until the profile arrives (up to 60 s,
    // because the first full sync can be slow on mobile data).
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      try {
        await SyncService.instance
            .syncNow()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('StartupDecider sync attempt $attempt skipped: $e');
      }
      final local = await _studentRepository.getCurrent();
      debugPrint(
        'StartupDecider: attempt $attempt, local profile present: ${local != null}',
      );
      if (local != null) return _CloudCheck.restored;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    debugPrint('StartupDecider: profile did not arrive locally after retries');
    return _CloudCheck.unreachable;
  }

  Future<void> _checkOnboardingStatus() async {
    if (!mounted) return;

    setState(() {
      _onboardingComplete = null;
      _cloudCheckFailed = false;
      _error = null;
    });

    try {
      var student = await _studentRepository.getCurrent();

      if (student == null && _signedIn) {
        final result = await _restoreFromCloud();
        student = await _studentRepository.getCurrent();

        if (student == null && result == _CloudCheck.unreachable) {
          if (!mounted) return;
          setState(() {
            _cloudCheckFailed = true;
          });
          return;
        }
      }

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
                    Text(
                      'We could not load your local profile. '
                      'Please try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.secondaryText,
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

    if (_cloudCheckFailed) {
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
                      Icons.cloud_off_rounded,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not reach your account.',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your profile may already be saved in your account. '
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.secondaryText,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _checkOnboardingStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _cloudCheckFailed = false;
                          _onboardingComplete = false;
                        });
                      },
                      child: const Text('Set up a new profile instead'),
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
      return const SplashView();
    }

    if (_onboardingComplete == false) {
      return OnboardingFlow(
        onComplete: _handleOnboardingComplete,
      );
    }

    return const MainScaffold();
  }
}
