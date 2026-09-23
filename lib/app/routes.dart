import 'package:flutter/material.dart';
import 'startup_decider.dart';
import '../screens/plan/plan_session_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const plan = '/plan';

  static Map<String, WidgetBuilder> get table => {
        root: (_) => const StartupDecider(),
        plan: (_) => const PlanSessionScreen(),
      };
}