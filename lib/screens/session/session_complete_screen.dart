import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/data_refresh_bus.dart';
import '../../models/study_session.dart';
import '../../repositories/session_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_helpers.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';

class _Mood {
  final String emoji;
  final String label;
  const _Mood(this.emoji, this.label);
}

const _moods = [
  _Mood('😫', 'Drained'),
  _Mood('😕', 'Meh'),
  _Mood('🙂', 'Okay'),
  _Mood('😄', 'Good'),
  _Mood('🤩', 'Great'),
];

/// V2 Step 8c: shown right after a focus session ends.
///
/// The session is ALREADY saved as completed by the Focus Timer, so
/// nothing is lost if this screen is closed. "Save & finish" adds the
/// optional mood (stored in the session's 1-5 `rating`) and notes.
class SessionCompleteScreen extends StatefulWidget {
  final StudySession session;
  final String subjectName;
  final int subjectColorValue;
  final String? topicName;
  final Duration goal;

  const SessionCompleteScreen({
    super.key,
    required this.session,
    required this.subjectName,
    required this.subjectColorValue,
    this.topicName,
    required this.goal,
  });

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SessionRepository();
  final _notesController = TextEditingController();

  late final AnimationController _confettiController;
  late final List<_ConfettiPiece> _pieces;

  int? _rating;
  bool _saving = false;
  String? _error;

  int get _focusedMinutes => widget.session.actualDuration ?? 0;

  bool get _goalReached => _focusedMinutes >= widget.goal.inMinutes;

  @override
  void initState() {
    super.initState();

    _notesController.text = widget.session.notes;
    _rating = widget.session.rating;

    final random = math.Random(7);
    const palette = [
      AppColors.primary,
      AppColors.teal,
      AppColors.accentBlueStrong,
      AppColors.accentPurpleStrong,
      AppColors.accentGreenStrong,
      Color(0xFFFFC857),
    ];

    _pieces = List.generate(42, (_) {
      return _ConfettiPiece(
        x: random.nextDouble(),
        startY: -random.nextDouble() * 0.25,
        speed: 0.7 + random.nextDouble() * 0.6,
        sway: 0.015 + random.nextDouble() * 0.03,
        phase: random.nextDouble() * math.pi * 2,
        spin: 2 + random.nextDouble() * 6,
        width: 6 + random.nextDouble() * 6,
        height: 10 + random.nextDouble() * 8,
        color: palette[random.nextInt(palette.length)],
      );
    });

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = widget.session.copyWith(
        rating: _rating,
        notes: _notesController.text.trim(),
      );

      await _repo.update(updated);

      DataRefreshBus.instance.notify(RefreshScope.sessions);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  void _skip() {
    Navigator.of(context).pop(false);
  }

  Widget _statCard({
    required String value,
    required String label,
    IconData? icon,
    Color? iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: context.cardSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 4),
            ],
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_moods.length, (i) {
        final value = i + 1;
        final selected = _rating == value;

        return GestureDetector(
          onTap: _saving
              ? null
              : () {
                  setState(() {
                    _rating = selected ? null : value;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : context.cardSurfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              _moods[i].emoji,
              style: TextStyle(fontSize: selected ? 32 : 28),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.subjectColorValue);
    final subtitle = widget.topicName == null
        ? widget.subjectName
        : '${widget.subjectName} · ${widget.topicName}';

    return Scaffold(
      body: GradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Session complete!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: context.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: context.secondaryText,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      _statCard(
                        value: _focusedMinutes == 0
                            ? '<1m'
                            : formatDuration(_focusedMinutes),
                        label: 'Focused',
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _statCard(
                        value: _goalReached
                            ? 'Goal reached'
                            : 'of ${formatDuration(widget.goal.inMinutes)}',
                        label: _goalReached ? 'Nice work' : 'Goal',
                        icon: _goalReached
                            ? Icons.emoji_events_rounded
                            : Icons.flag_rounded,
                        iconColor: _goalReached
                            ? const Color(0xFFFFB020)
                            : context.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'How did it feel?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _moodPicker(),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 20,
                    child: Text(
                      _rating == null ? '' : _moods[_rating! - 1].label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.secondaryText,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _notesController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Notes about this session (optional)',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Save & finish',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Skip',
                    onPressed: _saving ? null : _skip,
                  ),
                ],
              ),
            ),
            // Confetti sits on top and never blocks taps.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confettiController.value,
                        pieces: _pieces,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x; // 0..1 across the screen
  final double startY; // starts slightly above the screen
  final double speed;
  final double sway;
  final double phase;
  final double spin;
  final double width;
  final double height;
  final Color color;

  const _ConfettiPiece({
    required this.x,
    required this.startY,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.width,
    required this.height,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1
  final List<_ConfettiPiece> pieces;

  const _ConfettiPainter({
    required this.progress,
    required this.pieces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;

    // Fade everything out over the last 30% of the animation.
    final fade = progress < 0.7 ? 1.0 : (1 - (progress - 0.7) / 0.3);

    for (final p in pieces) {
      final y = (p.startY + p.speed * progress * 1.25) * size.height;
      if (y > size.height || y < -20) continue;

      final x = (p.x + math.sin(p.phase + progress * 6) * p.sway) * size.width;

      final paint = Paint()
        ..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + progress * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) {
    return old.progress != progress;
  }
}
