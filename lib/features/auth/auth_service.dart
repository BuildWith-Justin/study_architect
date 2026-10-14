import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../../services/sync_service.dart';
import 'offline_access.dart';

/// Thin wrapper around Supabase Auth so no screen talks to Supabase directly.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Set to true in main() only after Supabase.initialize succeeds.
  static bool isAvailable = false;

  /// True after the user taps "Not now" on the password banner.
  /// Lives in memory only, so the banner returns on the next app launch.
  static bool passwordPromptDismissed = false;

  SupabaseClient get _client => Supabase.instance.client;

  /// Deep link used to come back into the app after Google sign-in, after
  /// tapping the confirmation link in a sign-up email, or after tapping a
  /// password-reset link (Android/iOS/Windows).
  static const String mobileRedirect =
      'io.supabase.studyarchitect://login-callback/';

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Whether the signed-in user can sign in with email + password.
  /// True when the account has an email identity (email sign-up) or when a
  /// password was set through the app (has_password marker in metadata).
  /// A Google-only account returns false.
  bool get hasPassword {
    final user = currentUser;
    if (user == null) return true;
    if (user.userMetadata?['has_password'] == true) return true;
    final identities = user.identities ?? [];
    return identities.any((i) => i.provider == 'email');
  }

  // ---------------------------------------------------------------------------
  // Email + password
  // ---------------------------------------------------------------------------

  /// Creates an account with email and password.
  ///
  /// - emailRedirectTo sends the confirmation link back into the app
  ///   (without it the link opens the Site URL, which is localhost).
  /// - When "Confirm email" is ON, Supabase answers a sign-up for an address
  ///   that already exists with a fake success (no error, empty identities)
  ///   so attackers cannot discover registered emails. We detect that case and
  ///   raise a clear error instead of showing "check your inbox" for nothing.
  Future<AuthResponse> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'has_password': true},
      emailRedirectTo: kIsWeb ? null : mobileRedirect,
    );

    final identities = res.user?.identities;
    if (res.user != null && identities != null && identities.isEmpty) {
      throw AuthException('User already registered');
    }
    return res;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : mobileRedirect,
    );
  }

  /// Sets a new password for the account that is signed in right now.
  /// Used both after a reset link and from More > Password.
  /// For a Google-only account this adds a password, so the same email
  /// can also be used in the email sign-in form. The has_password marker
  /// stops the "Add a password" banner from showing again.
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'has_password': true},
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OAuth providers (Google now, others later)
  // ---------------------------------------------------------------------------

  /// Shared launcher so every provider behaves the same way.
  /// In-app browser (Chrome Custom Tab on Android) returns to the app
  /// reliably; a normal browser tab often stalls on a blank page.
  Future<bool> _signInWithOAuth(OAuthProvider provider) {
    return _client.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : mobileRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
    );
  }

  Future<bool> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  // Later, adding a provider is one line once it is enabled in Supabase:
  // Future<bool> signInWithGitHub() => _signInWithOAuth(OAuthProvider.github);

  /// Attaches another sign-in method to the account that is signed in now.
  /// Requires "Allow manual linking" to be enabled in Supabase.
  Future<bool> linkProvider(OAuthProvider provider) {
    return _client.auth.linkIdentity(
      provider,
      redirectTo: kIsWeb ? null : mobileRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
    );
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    passwordPromptDismissed = false;
    // Remember that this sign-out was the user's choice, so the app does
    // not treat them as "offline" and skip the sign-in screen.
    // Best effort: upload pending changes before leaving this account.
    try {
      await SyncService.instance.syncNow().timeout(const Duration(seconds: 10));
    } catch (_) {}
    await OfflineAccess.markSignedOut();
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  /// Turns Supabase errors into short, human messages.
  static String friendlyError(Object error) {
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login credentials')) {
        return 'Incorrect email or password. If you created your account with Google, tap "Continue with Google" instead.';
      }
      if (m.contains('email not confirmed')) {
        return 'Please confirm your email first. Check your inbox.';
      }
      if (m.contains('already registered') ||
          m.contains('already been registered')) {
        return 'An account with this email already exists. Try signing in, or tap "Continue with Google" if you signed up with Google.';
      }
      if (m.contains('different from the old password') ||
          m.contains('same as the old password')) {
        return 'Choose a password that is different from your current one.';
      }
      if (m.contains('reauthentication')) {
        return 'For security, please sign out, sign in again, then change your password.';
      }
      if (m.contains('auth session missing')) {
        return 'Your session expired. Please sign in again.';
      }
      if (m.contains('password should be at least')) {
        return 'Password is too short. Use at least 6 characters.';
      }
      if (m.contains('unable to validate email') ||
          m.contains('invalid email')) {
        return 'That email address does not look valid.';
      }
      if (m.contains('signups not allowed') ||
          m.contains('signup is disabled')) {
        return 'Sign-ups are currently turned off.';
      }
      if (m.contains('provider is not enabled') ||
          m.contains('unsupported provider')) {
        return 'This sign-in method is not enabled yet.';
      }
      if (m.contains('rate limit') || m.contains('too many requests')) {
        return 'Too many attempts. Please wait a minute and try again.';
      }
      return error.message;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('network')) {
      return 'No internet connection. Please check your network and retry.';
    }
    return 'Something went wrong. Please try again.';
  }
}
