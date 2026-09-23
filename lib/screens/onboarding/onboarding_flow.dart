import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/student.dart';
import '../../models/subject.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/gradient_background.dart';
import 'goal_setup_screen.dart';
import 'profile_setup_screen.dart';
import 'subject_setup_screen.dart';
import 'welcome_screen.dart';

/// Drives welcome -> profile -> daily goal -> first subject, then
/// writes a Student and a Subject through the repositories and hands
/// control back to the app.
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
  final _pageController = PageController();
  final _studentRepository = StudentRepository();
  final _subjectRepository = SubjectRepository();
  final _uuid = const Uuid();

  String _name = '';
  String _school = '';
  String _program = '';
  String _level = '';
  int _dailyGoalHours = 3;

  bool _saving = false;
  String? _error;

  void _next() {
    if (_saving) return;

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish({
    required String subjectName,
    required SubjectDifficulty difficulty,
    required int weeklyTargetHours,
    required int colorValue,
  }) async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final student = Student(
        id: _uuid.v4(),
        name: _name.trim(),
        school: _school.trim(),
        program: _program.trim(),
        level: _level.trim(),
        dailyGoalMinutes: _dailyGoalHours * 60,
        // V1 default: weekly goal follows the daily goal until
        // the user changes it from More/Settings.
        weeklyGoalMinutes: _dailyGoalHours * 60 * 7,
      );

      await _studentRepository.save(student);

      final subject = Subject(
        id: _uuid.v4(),
        name: subjectName.trim(),
        difficulty: difficulty,
        colorValue: colorValue,
        weeklyTargetMinutes: weeklyTargetHours * 60,
        createdAt: DateTime.now(),
      );

      await _subjectRepository.create(subject);

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

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      widget.onComplete();
    } catch (e, stackTrace) {
      debugPrint(
        'Onboarding save failed: $e\n$stackTrace',
      );

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
    if (_saving) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  WelcomeScreen(
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
                  ProfileSetupScreen(
                    onContinue: (
                      name,
                      school,
                      program,
                      level,
                    ) {
                      _name = name;
                      _school = school;
                      _program = program;
                      _level = level;
                      _next();
                    },
                  ),
                  GoalSetupScreen(
                    onContinue: (hours) {
                      _dailyGoalHours = hours;
                      _next();
                    },
                  ),
                  SubjectSetupScreen(
                    onSave: (
                      name,
                      difficulty,
                      weeklyTargetHours,
                      colorValue,
                    ) {
                      _finish(
                        subjectName: name,
                        difficulty: difficulty,
                        weeklyTargetHours: weeklyTargetHours,
                        colorValue: colorValue,
                      );
                    },
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
                          Expanded(
                            child: Text(_error!),
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
}