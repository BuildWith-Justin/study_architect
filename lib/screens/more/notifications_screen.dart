import 'package:flutter/material.dart';

import '../../repositories/settings_repository.dart';
import '../../services/app_prefs.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../widgets/gradient_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final _settingsRepo = SettingsRepository();
  final _service = NotificationService.instance;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _master = true;
  NotificationPrefs _prefs = const NotificationPrefs();
  bool? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the phone's system settings: re-check the permission.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _settingsRepo.get();
      final prefs = await AppPrefs.loadNotificationPrefs();
      bool? permission;
      try {
        permission = await _service.permissionGranted();
      } catch (_) {
        permission = null;
      }
      if (!mounted) return;
      setState(() {
        _master = settings.notificationsEnabled;
        _prefs = prefs;
        _permission = permission;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your reminder settings.';
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setMaster(bool value) => _run(() async {
        if (value) {
          final granted = await _service.requestPermissionAndCheck();
          if (granted == false) {
            _snack(
              'Notifications are blocked in your phone settings. '
              'Allow them there to receive reminders.',
            );
          }
        }
        await _service.setMasterEnabled(value);
        await _load();
      });

  Future<void> _updatePrefs(NotificationPrefs next) => _run(() async {
        setState(() => _prefs = next);
        await AppPrefs.saveNotificationPrefs(next);
        await _service.applyAll();
      });

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _prefs.effectiveDailyTime,
    );
    if (picked == null || !mounted) return;
    await _updatePrefs(_prefs.copyWith(dailyTime: picked, dailyEnabled: true));
  }

  Future<void> _askPermission() => _run(() async {
        final granted = await _service.requestPermissionAndCheck();
        await _load();
        if (granted == false) {
          _snack(
            "Still blocked. Open your phone's Settings > Apps > "
            'Study Architect > Notifications.',
          );
        }
      });

  Future<void> _sendTest() => _run(() async {
        if (_permission == false) {
          final granted = await _service.requestPermissionAndCheck();
          if (granted == false) {
            _snack('Notifications are blocked in your phone settings.');
            return;
          }
        }
        await _service.showTestNotification();
        _snack('Test notification sent.');
      });

  // ------------------------------------------------------------------ UI

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: context.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final subEnabled = _master && !_busy;

    return RefreshIndicator(
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
          if (_permission == false && _master)
            _card(
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_off_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Notifications are blocked for this app, so reminders '
                      'cannot appear.',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _askPermission,
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ),
          _card(
            child: _switchRow(
              title: 'Notifications',
              subtitle: 'Master switch for every reminder below',
              value: _master,
              onChanged: _busy ? null : _setMaster,
            ),
          ),
          Opacity(
            opacity: _master ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !subEnabled,
              child: Column(
                children: [
                  _card(
                    child: Column(
                      children: [
                        _switchRow(
                          title: 'Daily goal reminder',
                          subtitle: 'A nudge to keep your streak alive',
                          value: _prefs.dailyEnabled,
                          onChanged: (v) =>
                              _updatePrefs(_prefs.copyWith(dailyEnabled: v)),
                        ),
                        if (_prefs.dailyEnabled) ...[
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            onTap: _pickTime,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Reminder time',
                                      style: TextStyle(
                                        color: context.primaryText,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _prefs.effectiveDailyTime.format(context),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: context.secondaryText,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _switchRow(
                          title: 'Session reminders',
                          subtitle: 'Before a planned study session starts',
                          value: _prefs.sessionEnabled,
                          onChanged: (v) =>
                              _updatePrefs(_prefs.copyWith(sessionEnabled: v)),
                        ),
                        if (_prefs.sessionEnabled) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Remind me before the start',
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in AppPrefs.leadChoices)
                                ChoiceChip(
                                  label: Text('$m min'),
                                  selected: _prefs.sessionLeadMinutes == m,
                                  onSelected: (_) {
                                    _updatePrefs(
                                      _prefs.copyWith(sessionLeadMinutes: m),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Applies to sessions you save from now on.',
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _card(
                    child: _switchRow(
                      title: 'Exam reminders',
                      subtitle: 'The evening before (6 PM) and the exam '
                          'morning (7:30 AM)',
                      value: _prefs.examEnabled,
                      onChanged: (v) =>
                          _updatePrefs(_prefs.copyWith(examEnabled: v)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _sendTest,
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Send a test notification'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Reminders are set per device. On some phones, battery saver '
            'can delay them by a few minutes.',
            style: TextStyle(color: context.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Reminders'),
                leading: const BackButton(),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }
}
