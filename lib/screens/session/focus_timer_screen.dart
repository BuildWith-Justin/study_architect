import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/data_refresh_bus.dart';
import '../../models/study_session.dart';
import '../../repositories/session_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/gradient_background.dart';
import 'session_complete_screen.dart';

/// Runs a live study session, either against an existing planned
/// StudySession (pass [existingSessionId]) or as a fresh ad-hoc one
/// (leave it null — a new session is created immediately, in progress).
///
/// Elapsed time is always computed as DateTime.now().difference(startedAt)
/// minus accumulated pause time, never by counting timer ticks. Ticks
/// don't fire while the app is backgrounded, so a tick-counted timer
/// would silently lose that time; a timestamp diff recomputes correctly
/// the instant the UI updates again, however long the app was away.
///
/// V2 Step 8b: the display is a countdown ring (time remaining until
/// [goal]). Past the goal the ring turns green and the centre shows
/// overtime. The timing logic itself is unchanged from V1.
///
/// V2 Step 8c: ending the session saves it as completed straight away,
/// then opens the Session Complete screen (mood + notes + celebration).
/// The close (X) button asks first and discards a session that was
/// just started from scratch.
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

  bool get _overGoal => _elapsed >= widget.goal;

  Duration get _remaining {
    final r = widget.goal - _elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  Duration get _overtime => _overGoal ? _elapsed - widget.goal : Duration.zero;

  /// How much of the ring is still filled (1.0 at the start, 0.0 at the goal).
  double get _remainingFraction {
    final goalMs = widget.goal.inMilliseconds;
    if (goalMs <= 0) return 0;
    return (1 - _elapsed.inMilliseconds / goalMs).clamp(0.0, 1.0).toDouble();
  }

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
        (_isPaused ? now.difference(_pauseStartedAt!) : Duration.zero);

    final calculatedElapsed = now.difference(_startedAt!) - pausedSoFar;

    setState(() {
      _elapsed =
          calculatedElapsed.isNegative ? Duration.zero : calculatedElapsed;
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

  /// Saves the session as completed, then replaces this screen with
  /// the Session Complete screen. The finished session is stored
  /// BEFORE the next screen opens, so closing the app right after
  /// never loses it.
  Future<void> _endSession() async {
    if (_ending || _session == null) return;

    // Freeze the timer so no more time accumulates.
    _ticker?.cancel();
    _ticker = null;

    _refreshElapsed();

    final finalElapsed = _elapsed;

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
      );

      await _sessionRepo.update(updated);

      await NotificationService.instance.cancelSessionReminder(
        updated.id,
      );

      DataRefreshBus.instance.notify(RefreshScope.sessions);

      if (!mounted) return;

      Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute<bool>(
          builder: (_) => SessionCompleteScreen(
            session: updated,
            subjectName: widget.subjectName,
            subjectColorValue: widget.subjectColorValue,
            topicName: widget.topicName,
            goal: widget.goal,
          ),
        ),
        result: true,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _ending = false;
        _error = 'Could not save the session. Please try again.';
      });

      _startTicker();
    }
  }

  /// X button. A session started from scratch is discarded (so no
  /// half-finished "in progress" row is left behind); a planned
  /// session simply stays in progress.
  Future<void> _confirmClose() async {
    if (_ending) return;

    final isAdHoc = widget.existingSessionId == null;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isAdHoc ? 'Discard this session?' : 'Leave focus mode?'),
        content: Text(
          isAdHoc
              ? 'Your timer will stop and this session will not be saved.'
              : 'Your session stays in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep studying'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isAdHoc ? 'Discard' : 'Leave'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;

    _ticker?.cancel();
    _ticker = null;

    if (isAdHoc && _session != null) {
      try {
        await _sessionRepo.delete(_session!.id);
        DataRefreshBus.instance.notify(RefreshScope.sessions);
      } catch (_) {
        // Nothing useful to do; the user is leaving anyway.
      }
    }

    if (!mounted) return;

    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  /// mm:ss, or h:mm:ss once an hour or more is involved.
  String _clock(Duration d) {
    final hours = d.inHours;
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildLoadError() {
    return Center(
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Try Again',
              onPressed: _init,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(Color accent) {
    final screen = MediaQuery.of(context).size;
    final ringSize = math.min(screen.width * 0.66, screen.height * 0.34);

    final over = _overGoal;
    final ringColor = over ? AppColors.accentGreenStrong : accent;
    final ringFraction = over ? 1.0 : _remainingFraction;

    final centerText = over ? '+${_clock(_overtime)}' : _clock(_remaining);
    final centerLabel = _isPaused
        ? 'PAUSED'
        : over
            ? 'GOAL REACHED'
            : 'REMAINING';

    return FocusRing(
      size: ringSize,
      fraction: ringFraction,
      color: ringColor,
      trackColor: ringColor.withValues(alpha: 0.18),
      strokeWidth: 14,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                centerText,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ringColor,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              centerLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2,
                    color: AppColors.secondaryText(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final accent = Color(widget.subjectColorValue);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _ending ? null : _confirmClose,
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  widget.subjectName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.topicName != null)
                  Text(
                    widget.topicName!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText(context),
                        ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                _buildRing(accent),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Elapsed ${_clock(_elapsed)}  ·  Goal ${formatDuration(widget.goal.inMinutes)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText(context),
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
              hintText: 'Add a session note...',
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadii.control,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ending ? null : _togglePause,
                  icon: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(
                    _isPaused ? 'Resume' : 'Pause',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: _ending ? 'Saving...' : 'End Session',
            onPressed: _ending ? null : _endSession,
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
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _error != null && _session == null
                  ? _buildLoadError()
                  : _buildBody(),
        ),
      ),
    );
  }
}
