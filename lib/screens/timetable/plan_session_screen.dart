import 'package:flutter/material.dart';
import '../timetable/add_edit_session_screen.dart';

/// Pushed when the "+" nav item is tapped. Just forwards to the real
/// session form — kept as its own file/route in case the "+" flow
/// ever needs its own wrapper (e.g. picking Session vs Task) later.
class PlanSessionScreen extends StatelessWidget {
  const PlanSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AddEditSessionScreen();
  }
}