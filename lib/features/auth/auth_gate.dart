import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'offline_access.dart';
import 'local_owner_guard.dart';
import 'password_prompt_gate.dart';
import 'set_password_screen.dart';
import 'sign_in_screen.dart';

/// Decides what the user sees:
/// - Supabase not ready         -> your app shell directly (local-first fallback)
/// - password-reset link opened -> Set password screen
/// - session exists             -> your signed-in app shell, wrapped in the
///                                 password prompt (bottom sheet on entry)
/// - no session, but a profile is saved on this phone and the person did
///   not tap Sign out          -> the app shell in offline mode (an expired
///                                 login cannot refresh without internet)
/// - no session otherwise       -> Sign In screen
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
  bool _offlineNoticeShown = false;
  Future<bool>? _localAccessCheck;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      if (AuthService.instance.currentSession != null) {
        unawaited(OfflineAccess.clearSignedOut());
      }
      _sub = AuthService.instance.authStateChanges.listen((state) {
        if (!mounted) return;
        debugPrint(
          'AuthGate event: ${state.event.name}, session: ${state.session != null}',
        );
        if (state.session != null) {
          _offlineNoticeShown = false;
          unawaited(OfflineAccess.clearSignedOut());
        } else {
          // Re-check the saved-profile rule on the next build.
          _localAccessCheck = null;
        }
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

  void _showOfflineNotice() {
    if (_offlineNoticeShown) return;
    _offlineNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
            'Working offline. Your data is saved on this phone. '
            'Syncing resumes when you are back online and signed in.',
          ),
        ),
      );
    });
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
          _localAccessCheck ??= OfflineAccess.canUseWithoutSession();
          return FutureBuilder<bool>(
            future: _localAccessCheck,
            builder: (context, local) {
              if (local.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (local.data == true) {
                _showOfflineNotice();
                return widget.signedInBuilder(context);
              }
              return const SignInScreen();
            },
          );
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
          child: LocalOwnerGuard(
              userId: session.user.id, child: widget.signedInBuilder(context)),
        );
      },
    );
  }
}
