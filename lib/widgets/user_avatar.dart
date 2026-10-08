import 'dart:io';

import 'package:flutter/material.dart';

import '../services/avatar_service.dart';
import '../theme/app_theme.dart';

/// V2 Step 15: the one avatar used everywhere (Home, More, Edit profile).
/// Shows the real profile photo when there is one, otherwise the initial
/// on the green gradient circle (also while the photo is loading, or if it
/// cannot be loaded).
class UserAvatar extends StatefulWidget {
  final String name;
  final String? avatarPath;
  final double size;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarPath,
    this.size = 48,
    this.fontSize,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.avatarPath;
    final changed = oldWidget.avatarPath != path;
    // Also retry when a photo is expected but not on this device yet
    // (for example the download failed while offline).
    final missing = path != null &&
        path.isNotEmpty &&
        AvatarService.cachedFile(path) == null;
    if (changed || missing) {
      _future = _resolve();
    }
  }

  Future<File?>? _resolve() {
    final path = widget.avatarPath;
    if (path == null || path.isEmpty) return null;
    return AvatarService.localFileFor(path);
  }

  String _initial() {
    final trimmed = widget.name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  Widget _initialCircle() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.teal],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial(),
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.fontSize ?? widget.size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.avatarPath;
    final future = _future;

    if (path == null || path.isEmpty || future == null) {
      return _initialCircle();
    }

    return FutureBuilder<File?>(
      future: future,
      initialData: AvatarService.cachedFile(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _initialCircle();

        return ClipOval(
          child: Image.file(
            file,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: (widget.size * 3).round(),
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _initialCircle(),
          ),
        );
      },
    );
  }
}
