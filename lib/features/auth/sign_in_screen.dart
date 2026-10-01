import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email';
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.signInWithEmail(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      // AuthGate reacts to the new session automatically.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final launched = await AuthService.instance.signInWithGoogle();
      debugPrint('Google sign-in launched: $launched');
      if (!launched && mounted) {
        setState(() => _error =
            'Could not open the browser for Google sign-in. Please try again.');
      }
      // On success the browser opens; the session arrives through the deep link.
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailError = _validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() {
        _info = null;
        _error = 'Type your email above first, then tap "Forgot password?".';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.sendPasswordReset(_emailCtrl.text);
      if (mounted) {
        setState(() => _info = 'Password reset link sent. Check your inbox.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuthHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to continue your study journey',
              ),
              if (_error != null) AuthErrorBox(message: _error!),
              if (_info != null) AuthInfoBox(message: _info!),
              AuthTextField(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordCtrl,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                autofillHints: const [AutofillHints.password],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AuthColors.muted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AuthColors.primaryDark),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AuthPrimaryButton(
                label: 'Sign In',
                loading: _loading,
                onPressed: _signIn,
              ),
              const AuthDivider(),
              AuthGoogleButton(loading: _loading, onPressed: _google),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: AuthColors.muted),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AuthColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}