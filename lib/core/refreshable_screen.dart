import 'dart:async';
import 'package:flutter/material.dart';
import 'data_refresh_bus.dart';

/// Mixin any StatefulWidget's State with this to get:
/// - auto-refresh when relevant data changes elsewhere in the app
/// - pull-to-refresh wired to the same reload function
mixin RefreshableScreenMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<RefreshScope>? _refreshSub;

  /// Override: which scopes should trigger a refresh on this screen
  List<RefreshScope> get watchedScopes => [RefreshScope.all];

  /// Override: how this screen reloads its data
  Future<void> onRefresh();

  @override
  void initState() {
    super.initState();
    _refreshSub = DataRefreshBus.instance.stream.listen((scope) {
      if (watchedScopes.contains(scope) || scope == RefreshScope.all) {
        onRefresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Widget buildRefreshable({required Widget child}) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}