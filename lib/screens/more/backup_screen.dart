import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/startup_decider.dart';
import '../../features/auth/auth_service.dart';
import '../../gamification/gamification_hooks.dart';
import '../../core/data_refresh_bus.dart';
import '../../services/app_prefs.dart';
import '../../services/backup_service.dart';
import '../../services/account_reset_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/gradient_background.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();

  bool _busy = false;
  Map<String, int>? _counts;
  DateTime? _lastExport;

  bool get _signedIn =>
      AuthService.isAvailable && AuthService.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final counts = await _backupService.countLocal();
      final last = await AppPrefs.lastExportAt();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _lastExport = last;
      });
    } catch (e) {
      debugPrint('Backup screen load failed: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // -------------------------------------------------------------- export

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shared = await _backupService.shareBackup();
      if (shared) await AppPrefs.markExportedNow();
      await _load();
      _snack(shared ? 'Backup created.' : 'Export cancelled.');
    } catch (e) {
      _snack('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------- import

  Future<void> _import() async {
    if (_busy) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty) return;

      final path = result.first.path;
      if (path == null) {
        _snack('Could not access the selected file.');
        return;
      }

      if (!mounted) return;
      setState(() => _busy = true);

      final bytes = await File(path).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      final backup = _backupService.parseBackup(text);
      final counts = _backupService.describe(backup);

      if (!mounted) return;
      setState(() => _busy = false);

      final confirmed = await _confirmRestore(backup, counts);
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      await _backupService.saveSafetyCopy();
      await _backupService.restore(backup);
      await GamificationHooks.afterRestore();
      DataRefreshBus.instance.notify(RefreshScope.all);
      await _resetReminders();

      _snack('Backup restored.');
      _goToStartup();
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Restore failed: $e');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(
    Map<String, dynamic> backup,
    Map<String, int> counts,
  ) {
    final exportedAt = DateTime.tryParse('${backup['exportedAt'] ?? ''}');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exportedAt != null) ...[
                Text('Created ${_formatDateTime(exportedAt.toLocal())}'),
                const SizedBox(height: 8),
              ],
              Text(_countsLine(counts)),
              const SizedBox(height: 12),
              const Text(
                'This replaces ALL the data on this device. A safety copy '
                'of your current data is saved first.',
              ),
              if (_signedIn) ...[
                const SizedBox(height: 8),
                const Text(
                  'You are signed in, so the restored data will also sync '
                  'to your account.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- clear

  Future<void> _clearAll() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ClearDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountResetService.instance.wipeEverything();
      await _resetReminders();

      _snack('All data has been cleared.');
      _goToStartup();
    } catch (e) {
      _snack('Could not clear data: $e');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _resetReminders() async {
    try {
      await NotificationService.instance.cancelAllReminders();
      await NotificationService.instance.applyAll();
    } catch (e) {
      debugPrint('Reminder reset failed: $e');
    }
  }

  void _goToStartup() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const StartupDecider(),
      ),
      (route) => false,
    );
  }

  // ------------------------------------------------------------- helpers

  String _countsLine(Map<String, int> c) {
    return '${c['subjects'] ?? 0} subjects, ${c['topics'] ?? 0} topics, '
        '${c['sessions'] ?? 0} sessions, ${c['tasks'] ?? 0} tasks, '
        '${c['exams'] ?? 0} exams';
  }

  String _formatDateTime(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $h:$m';
  }

  String get _exportSubtitle {
    final last = _lastExport;
    if (last == null) return 'No export yet. Create a safety copy now.';
    final old = DateTime.now().difference(last).inDays > 30;
    return 'Last export: ${_formatDateTime(last)}'
        '${old ? ' (over 30 days ago)' : ''}';
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final user =
        AuthService.isAvailable ? AuthService.instance.currentUser : null;
    final counts = _counts;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  AppBar(
                    title: const Text('Data & Backup'),
                    leading: const BackButton(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl + MediaQuery.of(context).padding.bottom,
                        ),
                        children: [
                          _InfoCard(
                            icon: user != null
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            title: user != null
                                ? 'Synced to your account'
                                : 'Stored on this device only',
                            text: user != null
                                ? 'Your data syncs automatically '
                                    '(${user.email ?? 'signed in'}). '
                                    'An export is an extra safety copy that '
                                    'you keep yourself.'
                                : 'You are not signed in, so your data lives '
                                    'only on this device. Export a backup '
                                    'regularly.',
                          ),
                          if (counts != null) ...[
                            const _SectionTitle('On this device'),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: context.cardSurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.card),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _CountChip('Subjects', counts['subjects']),
                                  _CountChip('Topics', counts['topics']),
                                  _CountChip('Sessions', counts['sessions']),
                                  _CountChip('Tasks', counts['tasks']),
                                  _CountChip('Exams', counts['exams']),
                                  _CountChip('XP entries', counts['xpLog']),
                                  _CountChip(
                                    'Badges',
                                    counts['achievements'],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const _SectionTitle('Safety copy'),
                          _ActionTile(
                            icon: Icons.upload_file_rounded,
                            title: 'Export backup',
                            subtitle: _exportSubtitle,
                            onTap: _busy ? null : _export,
                          ),
                          _ActionTile(
                            icon: Icons.download_rounded,
                            title: 'Restore from a backup',
                            subtitle: 'Replace this device\'s data with a '
                                'backup file (.json)',
                            onTap: _busy ? null : _import,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: Text(
                              'Your profile photo is stored in your account, '
                              'not inside the backup file.',
                              style: TextStyle(
                                color: context.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const _SectionTitle('Danger zone'),
                          _ActionTile(
                            icon: Icons.delete_forever_rounded,
                            title: 'Clear all data',
                            subtitle: 'Permanently remove all Study '
                                'Architect data from this device and your account',
                            danger: true,
                            onTap: _busy ? null : _clearAll,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          color: context.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(color: context.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int? value;

  const _CountChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        '$label  ${value ?? 0}',
        style: TextStyle(color: context.primaryText, fontSize: 13),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              danger ? AppColors.danger : context.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks the person to type DELETE before everything is wiped.
class _ClearDialog extends StatefulWidget {
  const _ClearDialog();

  @override
  State<_ClearDialog> createState() => _ClearDialogState();
}

class _ClearDialogState extends State<_ClearDialog> {
  final _controller = TextEditingController();

  bool get _confirmed => _controller.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes all Study Architect data on this '
            'device. If you are signed in, it is also deleted from '
            'your account. You stay signed in and start a new profile.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('Clear everything'),
        ),
      ],
    );
  }
}
