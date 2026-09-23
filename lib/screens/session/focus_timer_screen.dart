import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/study_session.dart';
import '../../repositories/session_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/app_buttons.dart';

/// Runs a live study session, either against an existing planned
/// StudySession (pass [existingSessionId]) or as a fresh ad-hoc one
/// (leave it null — a new session is created immediately, in progress).
///
/// Elapsed time is always computed as DateTime.now().difference(startedAt)
/// minus accumulated pause time, never by counting timer ticks. Ticks
/// don't fire while the app is backgrounded, so a tick-counted timer
/// would silently lose that time; a timestamp diff recomputes correctly
/// the instant the UI updates again, however long the app was away.
class FocusTimerScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final int subjectColorValue;
  final String? topicId;
  final String? topicName;
  final String? existingSessionId;
  final Duration goal;

  const FocusTimerScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColorValue,
    this.topicId,
    this.topicName,
    this.existingSessionId,
    this.goal = const Duration(hours: 2),
  });

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with WidgetsBindingObserver {
  final _sessionRepo = SessionRepository();
  final _notesController = TextEditingController();

  StudySession? _session;
  DateTime? _startedAt;
  Duration _pausedAccum = Duration.zero;
  DateTime? _pauseStartedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  bool _loading = true;
  bool _ending = false;
  String? _error;

  bool get _isPaused => _pauseStartedAt != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.existingSessionId != null) {
        final existing = await _sessionRepo.getById(
          widget.existingSessionId!,
        );

        if (!mounted) return;

        if (existing != null) {
          // Resuming a session already marked in progress keeps its
          // original start timestamp. This keeps elapsed time correct
          // even if the screen was closed and reopened.
          final startedAt = existing.status == SessionStatus.inProgress
              ? existing.startTime
              : DateTime.now();

          final updated = existing.copyWith(
            status: SessionStatus.inProgress,
            startTime: startedAt,
          );

          await _sessionRepo.update(updated);

          if (!mounted) return;

          _session = updated;
          _startedAt = startedAt;
        }
      }

      if (_session == null) {
        final now = DateTime.now();

        final session = StudySession(
          id: const Uuid().v4(),
          subjectId: widget.subjectId,
          topicId: widget.topicId,
          scheduledDate: DateTime(
            now.year,
            now.month,
            now.day,
          ),
          startTime: now,
          // Placeholder end time to satisfy the repository's
          // end-after-start rule. Replaced when the session ends.
          endTime: now.add(widget.goal),
          status: SessionStatus.inProgress,
        );

        await _sessionRepo.create(session);

        if (!mounted) return;

        _session = session;
        _startedAt = now;
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
      });

      _startTicker();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not start the study session. Please try again.';
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshElapsed(),
    );

    _refreshElapsed();
  }

  void _refreshElapsed() {
    if (_startedAt == null || !mounted) return;

    final now = DateTime.now();

    final pausedSoFar = _pausedAccum +
        (_isPaused
            ? now.difference(_pauseStartedAt!)
            : Duration.zero);

    final calculatedElapsed =
        now.difference(_startedAt!) - pausedSoFar;

    setState(() {
      _elapsed = calculatedElapsed.isNegative
          ? Duration.zero
          : calculatedElapsed;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshElapsed();
    }
  }

  void _togglePause() {
    if (_ending || _startedAt == null) return;

    final now = DateTime.now();

    setState(() {
      if (_isPaused) {
        _pausedAccum += now.difference(_pauseStartedAt!);
        _pauseStartedAt = null;
      } else {
        _pauseStartedAt = now;
      }
    });

    _refreshElapsed();
  }

  Future<int?> _pickRating() {
    var rating = 0;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('How did it go?'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) {
                final filled = i < rating;

                return IconButton(
                  icon: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.accentPurpleStrong,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      rating = i + 1;
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  rating == 0 ? null : rating,
                );
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    if (_ending || _session == null) return;

    // Freeze the timer immediately so the rating dialog doesn't
    // allow more time to accumulate underneath it.
    _ticker?.cancel();
    _ticker = null;

    _refreshElapsed();

    final finalElapsed = _elapsed;

    final rating = await _pickRating();

    if (!mounted) return;

    setState(() {
      _ending = true;
      _error = null;
    });

    try {
      final now = DateTime.now();

      final updated = _session!.copyWith(
        endTime: now,
        actualDuration: finalElapsed.inMinutes,
        notes: _notesController.text.trim(),
        status: SessionStatus.completed,
        complete: true,
        rating: rating,
      );

      await _sessionRepo.update(updated);

      await NotificationService.instance.cancelSessionReminder(
        updated.id,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _ending = false;
        _error = 'Could not save the session. Please try again.';
      });

      _startTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.subjectColorValue);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _error != null && _session == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: 'Try Again',
                              onPressed: _init,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding:
                          const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _ending
                                    ? null
                                    : () {
                                        Navigator.of(context)
                                            .pop(false);
                                      },
                              ),
                            ],
                          ),
                          const Spacer(),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  widget.subjectName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                if (widget.topicName != null)
                                  Text(
                                    widget.topicName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors
                                              .textSecondary,
                                        ),
                                  ),
                                const SizedBox(
                                  height: AppSpacing.xl,
                                ),
                                Text(
                                  _formatElapsed(_elapsed),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.w600,
                                        color: accent,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'FOCUS TIME',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        letterSpacing: 2,
                                        color: AppColors
                                            .textSecondary,
                                      ),
                                ),
                                const SizedBox(
                                  height: AppSpacing.sm,
                                ),
                                Text(
                                  'Goal: ${widget.goal.inHours}h ${widget.goal.inMinutes % 60 == 0 ? '' : '${widget.goal.inMinutes % 60}m'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors
                                            .textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextField(
                            controller: _notesController,
                            enabled: !_ending,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Add a session note...',
                              filled: true,
                              fillColor:
                                  AppColors.surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  AppRadii.control,
                                ),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: AppSpacing.lg,
                          ),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.redAccent,
                                  ),
                            ),
                            const SizedBox(
                              height: AppSpacing.sm,
                            ),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _ending
                                      ? null
                                      : _togglePause,
                                  icon: Icon(
                                    _isPaused
                                        ? Icons
                                            .play_arrow_rounded
                                        : Icons.pause_rounded,
                                  ),
                                  label: Text(
                                    _isPaused
                                        ? 'Resume'
                                        : 'Pause',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          PrimaryButton(
                            label: _ending
                                ? 'Saving...'
                                : 'End Session',
                            onPressed: _ending
                                ? null
                                : _endSession,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}