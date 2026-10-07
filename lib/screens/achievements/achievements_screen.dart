import 'package:flutter/material.dart';

import '../../core/data_refresh_bus.dart';
import '../../core/refreshable_screen.dart';
import '../../gamification/badge_defs.dart';
import '../../gamification/gamification_engine.dart';
import '../../gamification/xp_rules.dart';
import '../../models/xp_entry.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/gradient_background.dart';

const _months = [
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

String _dateLabel(DateTime d) {
  final base = '${_months[d.month - 1]} ${d.day}';
  return d.year == DateTime.now().year ? base : '$base, ${d.year}';
}

/// Everything the screen shows, loaded in one pass.
class _AchievementsData {
  final GamificationSnapshot snapshot;
  final GamificationStats stats;
  final StreakInfo streak;
  final Map<String, DateTime> unlocked;
  final List<XpEntry> recentXp;

  const _AchievementsData({
    required this.snapshot,
    required this.stats,
    required this.streak,
    required this.unlocked,
    required this.recentXp,
  });

  static Future<_AchievementsData> load() async {
    final engine = GamificationEngine.instance;
    final snapshot = await engine.getSnapshot();
    final stats = await engine.getStats();
    final streak = await engine.getStreakInfo();
    final badges = await AchievementRepository().getAll();
    final xp = await XpRepository().getAll();

    return _AchievementsData(
      snapshot: snapshot,
      stats: stats,
      streak: streak,
      unlocked: {for (final a in badges) a.id: a.unlockedAt},
      recentXp: xp.take(8).toList(),
    );
  }
}

/// V2 Step 13e: level, streak, badges and recent XP in one place.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with RefreshableScreenMixin<AchievementsScreen> {
  late Future<_AchievementsData> _future;

  @override
  List<RefreshScope> get watchedScopes => [
        RefreshScope.achievements,
        RefreshScope.sessions,
        RefreshScope.tasks,
      ];

  @override
  void initState() {
    super.initState(); // RefreshableScreenMixin subscribes to the bus here.
    _future = _AchievementsData.load();
  }

  @override
  Future<void> onRefresh() async {
    final next = _AchievementsData.load();

    if (!mounted) {
      next.ignore();
      return;
    }

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the error state.
    }
  }

  Future<void> _recalculate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recalculate XP?'),
        content: const Text(
          'This re-checks every session, task and exam topic: it adds XP '
          'that is missing and removes XP whose session, task or topic no '
          'longer exists. Your badges are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final report = await GamificationEngine.instance.rebuildFromHistory(
        removeOrphans: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Done: ${report.written} added, ${report.removed} removed.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not recalculate XP.')),
      );
    }

    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Achievements'),
                leading: const BackButton(),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'recalc') _recalculate();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'recalc',
                        child: Text('Recalculate XP'),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<_AchievementsData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && !snapshot.hasError) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return buildRefreshable(
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Could not load your achievements.\n'
                                'Pull down to try again.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!;

                    return buildRefreshable(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        children: [
                          _levelCard(context, data),
                          const SizedBox(height: AppSpacing.md),
                          _streakRow(context, data),
                          const SizedBox(height: AppSpacing.lg),
                          _sectionTitle(
                            context,
                            'Badges · ${data.snapshot.badgesUnlocked} of '
                            '${data.snapshot.badgesTotal}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._badgeRows(data),
                          const SizedBox(height: AppSpacing.md),
                          _sectionTitle(context, 'Recent XP'),
                          const SizedBox(height: AppSpacing.sm),
                          _recentXp(context, data),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ UI pieces

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.primaryText,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _levelCard(BuildContext context, _AchievementsData d) {
    final theme = Theme.of(context);
    final softWhite = Colors.white.withValues(alpha: 0.85);
    final level = d.snapshot.level;

    final progressText = level.isMax
        ? 'Max level reached'
        : '${level.xpIntoLevel} / ${level.levelSize} XP · '
            '${level.xpToNext} XP to Level ${level.level + 1}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Text(
                  '${level.level}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${level.level}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      levelTitle(level.level),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: softWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: level.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressText,
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
          const SizedBox(height: 2),
          Text(
            '${d.snapshot.totalXp} XP in total',
            style: theme.textTheme.bodySmall?.copyWith(color: softWhite),
          ),
        ],
      ),
    );
  }

  Widget _streakRow(BuildContext context, _AchievementsData d) {
    String days(int n) => n == 1 ? '1 day' : '$n days';

    return Row(
      children: [
        _tile(
          context,
          icon: Icons.local_fire_department_rounded,
          value: days(d.streak.current.length),
          label: 'Current streak',
        ),
        const SizedBox(width: AppSpacing.md),
        _tile(
          context,
          icon: Icons.emoji_events_rounded,
          value: days(d.streak.best),
          label: 'Best streak',
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.cardSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _badgeRows(_AchievementsData d) {
    // Unlocked badges first (newest first), then the locked ones.
    final unlocked = kBadges.where((b) => d.unlocked.containsKey(b.id)).toList()
      ..sort((a, b) => d.unlocked[b.id]!.compareTo(d.unlocked[a.id]!));
    final locked = kBadges.where((b) => !d.unlocked.containsKey(b.id)).toList();
    final ordered = [...unlocked, ...locked];

    Widget card(BadgeDef b) => _BadgeCard(
          badge: b,
          unlockedAt: d.unlocked[b.id],
          progress: b.progress(d.stats),
        );

    final rows = <Widget>[];
    for (var i = 0; i < ordered.length; i += 2) {
      final right = i + 1 < ordered.length ? ordered[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(ordered[i])),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: right == null ? const SizedBox() : card(right),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _recentXp(BuildContext context, _AchievementsData d) {
    final theme = Theme.of(context);

    if (d.recentXp.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.cardSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Text(
          'No XP yet. Finish a focus session or complete a task to start.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.secondaryText,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < d.recentXp.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.recentXp[i].reason.isEmpty
                              ? 'XP earned'
                              : d.recentXp[i].reason,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.primaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _dateLabel(d.recentXp[i].earnedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${d.recentXp[i].amount} XP',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One badge: colored when unlocked, grey with a progress bar when not.
class _BadgeCard extends StatelessWidget {
  final BadgeDef badge;
  final DateTime? unlockedAt;
  final int progress;

  const _BadgeCard({
    required this.badge,
    required this.unlockedAt,
    required this.progress,
  });

  bool get _unlocked => unlockedAt != null;

  /// Minutes are shown as hours and minutes; everything else as a count.
  String _progressLabel() {
    final isMinutes = badge.id.startsWith('focus_') || badge.id == 'deep_focus';
    final shown = progress > badge.target ? badge.target : progress;
    if (isMinutes) {
      return '${formatDuration(shown)} / ${formatDuration(badge.target)}';
    }
    return '$shown / ${badge.target}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final neutralFill = context.isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.08);

    final fraction = badge.target == 0
        ? 0.0
        : (progress / badge.target).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _unlocked ? AppColors.primary : neutralFill,
            ),
            child: Icon(
              badge.icon,
              size: 26,
              color: _unlocked
                  ? Colors.white
                  : context.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _unlocked ? context.primaryText : context.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_unlocked)
            Text(
              'Unlocked ${_dateLabel(unlockedAt!)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: neutralFill,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _progressLabel(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
