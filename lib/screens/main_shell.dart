import 'package:flutter/material.dart';
import 'my_jobs_screen.dart';
import 'job_history_screen.dart';
import 'profile_screen.dart';

// Bottom-nav shell. "Sync Status"/"Sync Issues" (docs/rohit/06-vendor-app-screen-list.md
// "Sync") isn't a tab yet — there's no offline action queue to have sync
// status about until that phase is built (see job_detail_screen.dart's
// comment on why Execution actions are deferred).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [MyJobsScreen(), JobHistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'My Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Unused import guard note: AppColors isn't referenced directly in this file
// but keeping app_theme.dart imported here is intentional — every screen in
// _screens relies on it being initialized first via MaterialApp's theme.
