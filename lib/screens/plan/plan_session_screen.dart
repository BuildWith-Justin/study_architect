import 'package:flutter/material.dart';
import '../../widgets/screen_placeholder.dart';
import '../../widgets/gradient_background.dart';

/// Pushed when the "+" nav item is tapped. Full form (subject, topic,
/// date, start/end time, location, notes) is built in later steps
/// once Subjects (Step 7) and local storage (Step 4) exist.
class PlanSessionScreen extends StatelessWidget {
  const PlanSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Plan a session'),
                leading: const BackButton(),
              ),
              const Expanded(
                child: ScreenPlaceholder(
                  title: 'Plan your next study block',
                  note: 'Full form lands once Subjects and local storage exist.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}