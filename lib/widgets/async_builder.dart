import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helpers.dart';

/// A FutureBuilder wrapper that adds the three things almost every
/// screen in this app was missing before Step 16: a real error state
/// (instead of an endless spinner if something throws — the exact bug
/// StartupDecider had), an optional retry action, and a soft fade
/// between loading/error/content so screen transitions don't pop.
///
/// This does not change behavior for the happy path — it's a drop-in
/// replacement for `FutureBuilder(future: ..., builder: (context,
/// snapshot) { if (!snapshot.hasData) return CircularProgressIndicator();
/// ... })`.
class AsyncBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final String errorMessage;
  final VoidCallback? onRetry;

  const AsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorMessage = "Something went wrong loading this screen.",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        late final Widget child;
        late final String stateKey;

        if (snapshot.hasError) {
          child = _ErrorView(message: errorMessage, onRetry: onRetry, error: snapshot.error);
          stateKey = 'error';
        } else if (!snapshot.hasData) {
          child = const Center(child: CircularProgressIndicator());
          stateKey = 'loading';
        } else {
          child = builder(context, snapshot.data as T);
          // Was: 'data-${identityHashCode(snapshot.data)}'
          // That changed on every reload (new object every _load() call),
          // forcing AnimatedSwitcher to tear down and rebuild the whole
          // subtree — including IconButton tooltips/overlays — on every
          // single reload. That teardown-mid-rebuild is what triggered
          // the `_dependents.isEmpty` crash. A stable key here means we
          // only fade between loading/error/data states, not on every
          // refresh within the "data" state.
          stateKey = 'data';
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(stateKey), child: child),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Object? error;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 32, color: context.secondaryText),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondaryText),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}