import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/auth_service.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import 'goal_dial_screen.dart';
import 'profile_setup_screen.dart';
import 'subjects_setup_screen.dart';
import 'welcome_screen.dart';

/// Drives welcome -> profile -> daily goal (dial) -> subjects, then saves a
/// Student and its Subjects locally. SyncService uploads them to Supabase
/// (the database triggers stamp updatedAt), so there is no cloud code here.
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _pageCount = 4;

  final _pageController = PageController();
  final _studentRepository = StudentRepository();
  final _subjectRepository = SubjectRepository();
  final _uuid = const Uuid();

  int _page = 0;

  String _name = '';
  String _school = '';
  String _program = '';
  String _level = '';
  int _dailyGoalMinutes = 180;

  bool _saving = false;
  String? _error;

  // Kept across retries so a failed attempt never creates duplicates.
  String? _studentId;
  bool _studentSaved = false;
  final Set<String> _savedSubjectIds = {};

  void _goTo(int page) {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _next() => _goTo(_page + 1);

  Future<void> _finish(List<SubjectDraft> drafts) async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      _studentId ??= _uuid.v4();

      final student = Student(
        id: _studentId!,
        name: _name.trim(),
        school: _school.trim(),
        program: _program.trim(),
        level: _level.trim(),
        dailyGoalMinutes: _dailyGoalMinutes,
        // Weekly goal follows the daily goal until the user changes it
        // from More/Settings.
        weeklyGoalMinutes: _dailyGoalMinutes * 7,
      );

      if (_studentSaved) {
        await _studentRepository.update(student);
      } else {
        await _studentRepository.save(student);
        _studentSaved = true;
      }

      final now = DateTime.now();
      for (final d in drafts) {
        if (_savedSubjectIds.contains(d.id)) continue;

        await _subjectRepository.create(
          Subject(
            id: d.id,
            name: d.name.trim(),
            difficulty: d.difficulty,
            colorValue: d.colorValue,
            weeklyTargetMinutes: d.weeklyTargetHours * 60,
            createdAt: now,
          ),
        );
        _savedSubjectIds.add(d.id);
      }

      // Notification setup should not prevent onboarding from
      // completing if the platform rejects permission or scheduling.
      try {
        await NotificationService.instance.requestPermissions();

        await NotificationService.instance.scheduleDailyGoalReminder(
          const TimeOfDay(hour: 19, minute: 0),
        );
      } catch (e, stackTrace) {
        debugPrint(
          'Onboarding notification setup failed: $e\n$stackTrace',
        );
      }

      // Ask the sync layer to upload the new rows soon.
      if (AuthService.isAvailable) {
        SyncService.instance.scheduleSync();
      }

      if (!mounted) return;

      setState(() => _saving = false);

      widget.onComplete();
    } catch (e, stackTrace) {
      debugPrint('Onboarding save failed: $e\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not finish setup. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.xl,
                        0,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: _page > 0
                                ? IconButton(
                                    icon: Icon(
                                      Icons.arrow_back_rounded,
                                      color: onSurface,
                                    ),
                                    onPressed: () => _goTo(_page - 1),
                                  )
                                : null,
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _pageCount; i++)
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: i == _page ? 26 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i <= _page
                                          ? AppColors.primary
                                          : onSurface.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _KeepAlive(
                            child: WelcomeScreen(
                              onGetStarted: _next,
                              onImportExisting: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Import will be available from '
                                      'Backup & Restore.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _KeepAlive(
                            child: ProfileSetupScreen(
                              onContinue: (name, school, program, level) {
                                _name = name;
                                _school = school;
                                _program = program;
                                _level = level;
                                _next();
                              },
                            ),
                          ),
                          _KeepAlive(
                            child: GoalDialScreen(
                              initialMinutes: _dailyGoalMinutes,
                              onContinue: (minutes) {
                                _dailyGoalMinutes = minutes;
                                _next();
                              },
                            ),
                          ),
                          _KeepAlive(
                            child: SubjectsSetupScreen(onFinish: _finish),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!)),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                });
                              },
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_saving)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps each page alive so typed text and added subjects survive when
/// the user goes back and forward.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}