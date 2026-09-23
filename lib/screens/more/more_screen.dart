import 'package:flutter/material.dart';

import '../../app/theme_controller.dart';
import '../../repositories/settings_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_builder.dart';
import '../progress/progress_screen.dart';
import 'backup_screen.dart';
import 'edit_goals_screen.dart';
import 'edit_profile_screen.dart';
import 'more_view_data.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with WidgetsBindingObserver {
  late Future<MoreViewData> _future;

  final _settingsRepo = SettingsRepository();

  bool? _notificationOverride;
  bool _isUpdatingNotifications = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _future = MoreViewData.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final next = MoreViewData.load();

    if (!mounted) return;

    setState(() {
      _future = next;
    });

    try {
      await next;

      if (!mounted) return;

      setState(() {
        _notificationOverride = null;
      });
    } catch (_) {
      // AsyncBuilder handles the error state.
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (_isUpdatingNotifications) return;

    setState(() {
      _notificationOverride = enabled;
      _isUpdatingNotifications = true;
    });

    try {
      final current = await _settingsRepo.get();

      await _settingsRepo.save(
        current.copyWith(
          notificationsEnabled: enabled,
        ),
      );

      try {
        if (enabled) {
          await NotificationService.instance.scheduleDailyGoalReminder(
            const TimeOfDay(hour: 19, minute: 0),
          );
        } else {
          await NotificationService.instance.cancelDailyGoalReminder();
        }
      } catch (_) {
        // The setting was already saved.
        // A notification-service failure should not undo the UI change.
      }

      if (!mounted) return;

      final next = MoreViewData.load();

      setState(() {
        _future = next;
      });

      try {
        await next;
      } catch (_) {
        // AsyncBuilder handles the error state.
      }

      if (!mounted) return;

      setState(() {
        _notificationOverride = null;
        _isUpdatingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _notificationOverride = null;
        _isUpdatingNotifications = false;
      });

      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBuilder<MoreViewData>(
      future: _future,
      errorMessage: 'Could not load your profile.',
      onRetry: _reload,
      builder: (context, data) {
        final student = data.student;

        final notificationsEnabled =
            _notificationOverride ?? data.settings.notificationsEnabled;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'More',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),

              _SectionCard(
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        student: student,
                      ),
                    ),
                  );

                  if (changed == true && mounted) {
                    await _reload();
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accentPurpleStrong,
                      child: Text(
                        student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: TextStyle(
                              color: context.primaryText,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level ${student.level} • ${student.program}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditGoalsScreen(
                        student: student,
                      ),
                    ),
                  );

                  if (changed == true && mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Study Goals',
                  'Daily ${formatDuration(student.dailyGoalMinutes)} • '
                      'Weekly ${formatDuration(student.weeklyGoalMinutes)}',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        color: context.primaryText,
                      ),
                    ),
                    Switch(
                      value: notificationsEnabled,
                      activeColor: AppColors.accentPurpleStrong,
                      onChanged: _isUpdatingNotifications
                          ? null
                          : _toggleNotifications,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: context.primaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.instance.mode,
                      builder: (context, mode, _) {
                        return SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) {
                            ThemeController.instance.setMode(s.first);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProgressScreen(),
                    ),
                  );

                  if (mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Progress',
                  'Charts, streak, insights',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BackupScreen(),
                    ),
                  );

                  if (mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Data & Backup',
                  'Export or import',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Study Architect',
                    applicationVersion: 'V1',
                    children: const [
                      Text(
                        'A local-first study planning and tracking app.',
                      ),
                    ],
                  );
                },
                child: _rowLabelValue(
                  'About',
                  'Study Architect V1',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rowLabelValue(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.primaryText,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: card,
      ),
    );
  }
}