import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/local_owner_service.dart';
import '../../widgets/splash_view.dart';

/// Shows the splash while the app checks that the data on this phone
/// belongs to the account that just signed in, then shows [child].
/// A failed check never blocks the app.
class LocalOwnerGuard extends StatefulWidget {
  final String userId;
  final Widget child;

  const LocalOwnerGuard({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  State<LocalOwnerGuard> createState() => _LocalOwnerGuardState();
}

class _LocalOwnerGuardState extends State<LocalOwnerGuard> {
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _run();
  }

  @override
  void didUpdateWidget(LocalOwnerGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _ready = _run();
    }
  }

  Future<void> _run() async {
    try {
      await LocalOwnerService.instance.ensureOwner(widget.userId);
    } catch (e) {
      debugPrint('LocalOwnerGuard: owner check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashView();
        }
        return widget.child;
      },
    );
  }
}
