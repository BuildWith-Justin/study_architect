import 'package:flutter/material.dart';

import '../../app/theme_controller.dart';
import '../../repositories/settings_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_builder.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/password_prompt_card.dart';
import '../../features/auth/set_password_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../features/auth/auth_diagnostics_screen.dart';
import '../achievements/achievements_screen.dart';
import '../calendar/calendar_screen.dart';
import '../progress/progress_screen.dart';
import '../tasks/tasks_screen.dart';
import 'backup_screen.dart';
import 'edit_goals_screen.dart';
import 'edit_profile_screen.dart';
import 'more_view_data.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with WidgetsBindingObserver {
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

  /// Asks for confirmation, then signs out through Supabase.
  /// AuthGate listens to the auth stream and switches to the Sign In
  /// screen by itself, so no manual navigation is needed here.
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use your account on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Color(0xFFD64545)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.friendlyError(e))),
      );
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

        // Only show the Sign out card when Supabase is running and
        // someone is actually signed in.
        final authUser =
            AuthService.isAvailable ? AuthService.instance.currentUser : null;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.of(context).padding.bottom + 96,
            ),
            children: [
              Text(
                'More',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),

              const PasswordPromptCard(),

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
                      builder: (_) => const CalendarScreen(),
                    ),
                  );

                  if (mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Calendar',
                  'Month view, study heatmap',
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
                      builder: (_) => const TasksScreen(),
                    ),
                  );

                  if (mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Tasks',
                  'Assignments, readings, revision',
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              _SectionCard(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  );

                  if (mounted) {
                    await _reload();
                  }
                },
                child: _rowLabelValue(
                  'Achievements',
                  'Level, XP, badges',
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

              // ---- V2: set or change password ----
              if (authUser != null) ...[
                _SectionCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SetPasswordScreen(),
                    ),
                  ),
                  child: _rowLabelValue('Password', 'Set or change'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ---- V2: debug-only auth diagnostics ----
              if (kDebugMode) ...[
                _SectionCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuthDiagnosticsScreen(),
                    ),
                  ),
                  child: _rowLabelValue('Auth diagnostics', 'Debug only'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ---- V2: Account / Sign out ----
              if (authUser != null) ...[
                _SectionCard(
                  onTap: _confirmSignOut,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD64545),
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sign out',
                              style: TextStyle(
                                color: Color(0xFFD64545),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if ((authUser.email ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                authUser.email!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

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
