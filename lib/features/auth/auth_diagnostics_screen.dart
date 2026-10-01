import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Debug-only screen that tests the auth system beyond "did login work?".
/// Never prints tokens. Safe to keep in the project; it is only reachable
/// from the More screen when running in debug mode.
class AuthDiagnosticsScreen extends StatefulWidget {
  const AuthDiagnosticsScreen({super.key});

  @override
  State<AuthDiagnosticsScreen> createState() => _AuthDiagnosticsScreenState();
}

class _Check {
  final String name;
  final bool ok;
  final String detail;
  const _Check(this.name, this.ok, this.detail);
}

class _AuthDiagnosticsScreenState extends State<AuthDiagnosticsScreen> {
  final List<_Check> _checks = [];
  final List<String> _events = [];
  StreamSubscription<AuthState>? _sub;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _sub = AuthService.instance.authStateChanges.listen((state) {
        if (!mounted) return;
        setState(() => _events.insert(0, '${_now()}  ${state.event.name}'));
      });
    }
    _runChecks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _now() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String _timeLeft(Duration d) {
    if (d.isNegative) return 'already expired';
    if (d.inMinutes < 1) return 'in under a minute';
    if (d.inHours < 1) return 'in ${d.inMinutes} min';
    return 'in ${d.inHours} h ${d.inMinutes % 60} min';
  }

  Future<void> _runChecks() async {
    setState(() {
      _running = true;
      _checks.clear();
    });

    final results = <_Check>[];

    void finish() {
      if (!mounted) return;
      setState(() {
        _checks
          ..clear()
          ..addAll(results);
        _running = false;
      });
    }

    // 1. Client initialized
    results.add(_Check(
      'Supabase initialized',
      AuthService.isAvailable,
      AuthService.isAvailable
          ? 'Client is ready'
          : 'main() could not start Supabase. Check the .env file.',
    ));
    if (!AuthService.isAvailable) {
      finish();
      return;
    }

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    // 2. Session exists
    results.add(_Check(
      'Session present',
      session != null && user != null,
      session != null ? 'A session is stored on this device' : 'No one is signed in',
    ));
    if (session == null || user == null) {
      finish();
      return;
    }

    // 3. Account info
    results.add(_Check(
      'Signed-in account',
      true,
      '${user.email ?? 'no email'}\nid: ${user.id}',
    ));

    // 4. Token expiry
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (session.expiresAt ?? 0) * 1000,
    );
    results.add(_Check(
      'Access token valid',
      !session.isExpired,
      'Expires ${_timeLeft(expiry.difference(DateTime.now()))}',
    ));

    // 5. Server accepts the token
    try {
      final res = await client.auth.getUser();
      final same = res.user?.id == user.id;
      results.add(_Check(
        'Server accepts the token',
        same,
        same
            ? 'Supabase verified this user'
            : 'Server returned a different user',
      ));
    } catch (e) {
      results.add(_Check(
        'Server accepts the token',
        false,
        AuthService.friendlyError(e),
      ));
    }

    // 6. Token refresh works
    try {
      final res = await client.auth.refreshSession();
      results.add(_Check(
        'Token refresh works',
        res.session != null,
        res.session != null
            ? 'New token issued, expires ${_timeLeft(DateTime.fromMillisecondsSinceEpoch((res.session!.expiresAt ?? 0) * 1000).difference(DateTime.now()))}'
            : 'Refresh returned no session',
      ));
    } catch (e) {
      results.add(_Check(
        'Token refresh works',
        false,
        AuthService.friendlyError(e),
      ));
    }

    // 7. Linked sign-in methods
    final providers = (user.identities ?? []).map((i) => i.provider).toSet();
    results.add(_Check(
      'Linked sign-in methods',
      providers.isNotEmpty,
      providers.isEmpty ? 'None reported' : providers.join(', '),
    ));

    // 8. Email confirmed
    results.add(_Check(
      'Email confirmed',
      user.emailConfirmedAt != null,
      user.emailConfirmedAt != null
          ? 'Confirmed'
          : 'Not confirmed (expected only if email confirmation is off)',
    ));

    finish();
  }

  Future<void> _copyReport() async {
    final buffer = StringBuffer('Auth diagnostics ${DateTime.now()}\n');
    for (final c in _checks) {
      buffer.writeln('[${c.ok ? 'OK' : 'FAIL'}] ${c.name}: ${c.detail}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            onPressed: _checks.isEmpty ? null : _copyReport,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _running ? null : _runChecks,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_running ? 'Running checks...' : 'Run checks again'),
          ),
          const SizedBox(height: 16),
          for (final c in _checks)
            Card(
              child: ListTile(
                leading: Icon(
                  c.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: c.ok ? Colors.green : Colors.red,
                ),
                title: Text(c.name),
                subtitle: Text(c.detail),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Auth events since this screen opened',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            const Text('No events yet.')
          else
            for (final e in _events) Text(e),
        ],
      ),
    );
  }
}