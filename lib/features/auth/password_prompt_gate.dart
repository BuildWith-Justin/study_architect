import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import 'auth_service.dart';
import 'set_password_screen.dart';

/// Wraps the signed-in app. A few seconds after entry it slides up a bottom
/// sheet inviting the user to add a password, when the account has none
/// (for example a Google-only account).
///
/// Rules:
/// - Shown at most once per app launch for each user.
/// - Skipped when the account already has a password.
/// - Skipped for accounts created in the last few minutes, so it does not
///   land on top of onboarding. Those users still get the banner on More and
///   see this sheet on their next launch.
/// - "Not now" only closes the sheet. The More banner stays as a reminder.
class PasswordPromptGate extends StatefulWidget {
  final Widget child;

  const PasswordPromptGate({super.key, required this.child});

  @override
  State<PasswordPromptGate> createState() => _PasswordPromptGateState();
}

class _PasswordPromptGateState extends State<PasswordPromptGate> {
  /// Id of the user who has already seen the sheet in this launch.
  static String? _promptedUserId;

  /// How long to wait after entering the app before showing the sheet.
  static const Duration _delay = Duration(milliseconds: 2500);

  /// Accounts younger than this are treated as brand new (likely onboarding).
  /// Set to Duration.zero while testing with a fresh account.
  static const Duration _newAccountGrace = Duration(minutes: 10);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_eligible()) {
      _timer = Timer(_delay, _maybeShow);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _eligible() {
    if (!AuthService.isAvailable) return false;
    final user = AuthService.instance.currentUser;
    if (user == null) return false;
    if (AuthService.instance.hasPassword) return false;
    if (_promptedUserId == user.id) return false;

    final created = DateTime.tryParse(user.createdAt);
    if (created != null &&
        DateTime.now().toUtc().difference(created.toUtc()) < _newAccountGrace) {
      return false;
    }
    return true;
  }

  Future<void> _maybeShow() async {
    if (!mounted || !_eligible()) return;

    // Do not cover another screen (a pushed page or a dialog).
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    _promptedUserId = AuthService.instance.currentUser?.id;

    final wantsToSet = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.cardSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => const _PasswordSheet(),
    );

    if (wantsToSet == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PasswordSheet extends StatelessWidget {
  const _PasswordSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentPurpleStrong.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.accentPurpleStrong,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add a password',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'You signed in with Google. Add a password so you can also '
              'sign in with your email if Google is ever unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPurpleStrong,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Set password'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Not now',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}