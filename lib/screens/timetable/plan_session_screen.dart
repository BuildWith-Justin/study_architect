import 'package:flutter/material.dart';
import '../session/create_session_screen.dart';

/// Pushed when the "+" nav item is tapped (route /plan).
/// V2 Step 8a: shows the Create Session screen, which offers
/// "Start focus now" or "Schedule for later" (the Step 7b form,
/// unchanged).
class PlanSessionScreen extends StatelessWidget {
  const PlanSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateSessionScreen();
  }
}
