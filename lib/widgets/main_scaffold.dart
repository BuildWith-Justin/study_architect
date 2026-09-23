import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/timetable/timetable_screen.dart';
import '../screens/subjects/subjects_screen.dart';
import '../screens/more/more_screen.dart';
import '../app/routes.dart';
import 'gradient_background.dart';

/// Hosts the four persistent tabs and the "+" nav item.
/// "+" is index 2 in the bar but is not a tab — tapping it pushes
/// the Plan-a-session screen on top of whatever tab is active.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _tabIndex = 0;

  // Maps the 5 bottom-nav slots to the 4 real tabs.
  // Slot 2 ("+") never becomes the selected tab.
  static const _tabForSlot = {0: 0, 1: 1, 3: 2, 4: 3};

  final _screens = [
    HomeScreen(),
    TimetableScreen(),
    SubjectsScreen(),
    MoreScreen(),
  ];

  void _onNavTap(int slot) {
    if (slot == 2) {
      Navigator.of(context).pushNamed(AppRoutes.plan);
      return;
    }

    setState(() => _tabIndex = _tabForSlot[slot]!);
  }

  int get _selectedSlot {
    switch (_tabIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedSlot,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Timetable',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_rounded),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Subjects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}