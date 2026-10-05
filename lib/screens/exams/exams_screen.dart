import 'package:flutter/material.dart';

import '../../widgets/gradient_background.dart';
import 'exams_view.dart';

/// Standalone exams list, opened from "See all exams" on Home.
class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Exams'),
                leading: const BackButton(),
              ),
              const Expanded(child: ExamsView()),
            ],
          ),
        ),
      ),
    );
  }
}
