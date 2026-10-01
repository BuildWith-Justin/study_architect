import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'password_prompt_gate.dart';
import 'set_password_screen.dart';
import 'sign_in_screen.dart';

/// Decides what the user sees:
/// - Supabase not ready         -> your app shell directly (local-first fallback)
/// - password-reset link opened -> Set password screen
/// - session exists             -> your signed-in app shell, wrapped in the
///                                 password prompt (bottom sheet on entry)
/// - no session                 -> Sign In screen
/// It listens to Supabase, so sign-in, sign-out and expired sessions
/// switch screens automatically with no manual navigation.
class AuthGate extends StatefulWidget {
  /// Your existing V1 shell (the screen with Home • Timetable • + • Subjects • More).
  final WidgetBuilder signedInBuilder;

  const AuthGate({super.key, required this.signedInBuilder});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _recovering = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _sub = AuthService.instance.authStateChanges.listen((state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          setState(() => _recovering = true);
        } else if (state.event == AuthChangeEvent.signedOut && _recovering) {
          setState(() => _recovering = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Supabase failed to start (missing .env, bad key...): keep the
    // local-first app usable instead of trapping the user on a login
    // screen that can never succeed.
    if (!AuthService.isAvailable) {
      return widget.signedInBuilder(context);
    }

    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        AuthService.instance.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return const SignInScreen();
        }
        if (_recovering) {
          return SetPasswordScreen(
            recoveryMode: true,
            onDone: () {
              if (mounted) setState(() => _recovering = false);
            },
          );
        }
        return PasswordPromptGate(
          child: widget.signedInBuilder(context),
        );
      },
    );
  }
}