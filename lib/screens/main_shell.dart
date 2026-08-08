import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/push_providers.dart';
import '../providers/sync_providers.dart';
import 'dashboard_screen.dart';
import 'my_jobs_screen.dart';
import 'job_history_screen.dart';
import 'profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: const PageStorageKey('dashboard')),
      MyJobsScreen(key: const PageStorageKey('my-jobs')),
      JobHistoryScreen(key: const PageStorageKey('job-history')),
      ProfileScreen(key: const PageStorageKey('profile')),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).syncAll();
      ref.read(pushNotificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      extendBody: false,
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                border: Border(
                    top: BorderSide(
                        color: Theme.of(context).dividerColor, width: 1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4))
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                backgroundColor: Colors.transparent,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'Dashboard'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.work_outline),
                      activeIcon: Icon(Icons.work),
                      label: 'My Jobs'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.history), label: 'History'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
