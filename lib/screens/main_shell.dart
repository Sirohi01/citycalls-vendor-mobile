import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/push_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'my_jobs_screen.dart';
import 'job_history_screen.dart';
import 'profile_screen.dart';

// Bottom-nav shell. "Sync Status"/"Sync Issues" (docs/rohit/06-vendor-app-screen-list.md
// "Sync") is reachable from Dashboard/Profile rather than its own tab (see
// sync_status_screen.dart) — this is also where the sync engine's
// connectivity watcher gets started, once per app session.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _screens = [DashboardScreen(), MyJobsScreen(), JobHistoryScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    // Reading (not watching) is enough — this just needs the provider to be
    // instantiated so its connectivity listener starts; MainShell doesn't
    // need to rebuild when sync state changes (screens that display it watch
    // pendingActionsProvider themselves).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).syncAll();
      ref.read(pushNotificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Foreground messages don't produce a system notification banner on
    // their own (that's OS behavior for background/terminated apps only) —
    // shown as an in-app SnackBar instead, since the technician is already
    // looking at the app when these arrive (e.g. a new job just got assigned
    // while they're on the Dashboard).
    ref.listen(foregroundPushMessageProvider, (previous, next) {
      final message = next.valueOrNull;
      final title = message?.notification?.title;
      final body = message?.notification?.body;
      if (body == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(title != null ? '$title: $body' : body)),
      );
    });

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              border: const Border(top: BorderSide(color: Colors.white, width: 1)),
              boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'My Jobs'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
