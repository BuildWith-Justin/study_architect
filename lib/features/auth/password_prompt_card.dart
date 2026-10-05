import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import 'auth_service.dart';
import 'set_password_screen.dart';

/// Banner shown at the top of the More screen when the signed-in account has
/// no password (for example, a Google-only account).
/// - Hidden when Supabase is unavailable, nobody is signed in, the account
///   already has a password, or the user tapped "Not now" this session.
/// - Rebuilds itself when the auth state changes, so it disappears as soon as
///   a password is saved.
class PasswordPromptCard extends StatefulWidget {
  const PasswordPromptCard({super.key});

  @override
  State<PasswordPromptCard> createState() => _PasswordPromptCardState();
}

class _PasswordPromptCardState extends State<PasswordPromptCard> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _sub = AuthService.instance.authStateChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openSetPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
    );
    if (mounted) setState(() {});
  }

  void _dismiss() {
    setState(() => AuthService.passwordPromptDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAvailable) return const SizedBox.shrink();
    if (AuthService.instance.currentUser == null)
      return const SizedBox.shrink();
    if (AuthService.instance.hasPassword) return const SizedBox.shrink();
    if (AuthService.passwordPromptDismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: AppColors.accentPurpleStrong.withOpacity(0.55),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accentPurpleStrong,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Add a password',
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'You signed in with Google. Add a password so you can also '
              'sign in with your email if Google is ever unavailable.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FilledButton(
                  onPressed: _openSetPassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPurpleStrong,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Set password'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: _dismiss,
                  child: const Text(
                    'Not now',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
