import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';

/// Screen to choose a new password. Two ways to reach it:
///
/// - recoveryMode = true : shown by AuthGate after the user taps the link in
///   a password-reset email. There is no back button; the user either saves
///   a password or cancels (which signs them out).
/// - recoveryMode = false: opened from More > Password by a signed-in user
///   who wants to set or change their password.
class SetPasswordScreen extends StatefulWidget {
  final bool recoveryMode;

  /// Called in recovery mode once the flow is finished (saved or cancelled).
  final VoidCallback? onDone;

  const SetPasswordScreen({
    super.key,
    this.recoveryMode = false,
    this.onDone,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.updatePassword(_passwordCtrl.text);
      if (!mounted) return;

      if (widget.recoveryMode) {
        widget.onDone?.call();
      } else {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Password updated.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRecovery() async {
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Even if sign-out fails, leave the recovery screen.
    }
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final recovery = widget.recoveryMode;

    return AuthBackground(
      child: Column(
        children: [
          if (!recovery)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AuthColors.text),
              ),
            ),
          AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AuthHeader(
                    title: recovery ? 'Choose a new password' : 'Set your password',
                    subtitle: recovery
                        ? 'Enter a new password for your account'
                        : 'Use it to sign in with your email, alongside any other method',
                  ),
                  if (_error != null) AuthErrorBox(message: _error!),
                  AuthTextField(
                    controller: _passwordCtrl,
                    label: 'New password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Use at least 6 characters'
                        : null,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirmCtrl,
                    label: 'Confirm new password',
                    icon: Icons.lock_reset_outlined,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v != _passwordCtrl.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: 'Save password',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  if (recovery) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _cancelRecovery,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AuthColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}