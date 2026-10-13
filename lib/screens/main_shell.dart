import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_navigator.dart';
import '../models/job_models.dart';
import '../providers/auth_providers.dart';
import '../providers/job_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/push_providers.dart';
import '../providers/sync_providers.dart';
import '../providers/transit_tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'my_jobs_screen.dart';
import 'job_history_screen.dart';
import 'notification_center_screen.dart';
import 'profile_screen.dart';

// Field-work shell (EMPLOYEE / TECHNICIAN / VENDOR_TECHNICIAN) — see
// role_router.dart. Laid out like citycalls-customer-mobile's MainShell.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  // Jobs are re-fetched on this cadence while the app is open, so a newly
  // assigned job shows up even when push isn't available on the device.
  static const _refreshEvery = Duration(seconds: 60);

  int _index = 0;
  // Tabs visited before the current one, most recent last — the phone's
  // back button walks back through these instead of closing the app.
  final List<int> _tabHistory = [];
  Timer? _refreshTimer;
  ProviderSubscription<AsyncValue<List<JobSummary>>>? _jobsSub;

  static const _tabs = [
    DashboardScreen(key: PageStorageKey('dashboard')),
    MyJobsScreen(key: PageStorageKey('my-jobs')),
    JobHistoryScreen(key: PageStorageKey('job-history')),
    ProfileScreen(key: PageStorageKey('profile')),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pendingShellTab.addListener(_applyPendingTab);

    // Keep live-location pings running for every job the technician is
    // travelling to, whatever screen they're on (transit_tracking_provider).
    _jobsSub = ref.listenManual<AsyncValue<List<JobSummary>>>(myJobsProvider,
        (_, next) {
      final jobs = next.valueOrNull;
      if (jobs == null) return;
      ref.read(transitTrackerProvider).update(jobs
          .where((j) => j.status == 'TECHNICIAN_EN_ROUTE')
          .map((j) => j.id));
    }, fireImmediately: true);

    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refreshJobs());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).syncAll();
      final role = ref.read(authProvider).user?.role;
      ref.read(pushNotificationServiceProvider).initialize(
          canRegisterToken: role == 'EMPLOYEE' || role == 'TECHNICIAN');
      _applyPendingTab();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingShellTab.removeListener(_applyPendingTab);
    _refreshTimer?.cancel();
    _jobsSub?.close();
    super.dispose();
  }

  // Coming back to the app is when queued offline work most likely can go
  // out, and when the job list is most likely stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider).syncAll();
      _refreshJobs();
    }
  }

  void _refreshJobs() {
    if (!mounted) return;
    ref.invalidate(allJobsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  void _applyPendingTab() {
    final requested = pendingShellTab.value;
    if (requested == null || !mounted) return;
    pendingShellTab.value = null;
    _selectTab(requested);
    _refreshJobs();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() {
      _tabHistory
        ..remove(_index)
        ..add(_index);
      _index = index;
    });
  }

  void _handleBack() {
    setState(() {
      _index = _tabHistory.isNotEmpty ? _tabHistory.removeLast() : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(foregroundPushMessageProvider, (previous, next) {
      final message = next.valueOrNull;
      if (message == null) return;
      // A push usually means a job changed — refresh without waiting for
      // the technician to pull-to-refresh.
      _refreshJobs();
      ref.invalidate(notificationsProvider);

      final title = message.notification?.title;
      final body = message.notification?.body;
      if (body == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(title != null ? '$title: $body' : body),
          action: SnackBarAction(
            label: 'View',
            textColor: AppColors.lime400,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen())),
          ),
        ),
      );
    });

    final newJobs = ref
            .watch(myJobsProvider)
            .valueOrNull
            ?.where((j) => newJobStatuses.contains(j.status))
            .length ??
        0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _tabHistory.isEmpty && _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          body: IndexedStack(index: _index, children: _tabs),
          bottomNavigationBar: AppBottomNav(
            currentIndex: _index,
            onTap: _selectTab,
            items: [
              const AppNavItemData(
                  icon: Icons.space_dashboard_outlined,
                  activeIcon: Icons.space_dashboard_rounded,
                  label: 'Home'),
              AppNavItemData(
                  icon: Icons.work_outline_rounded,
                  activeIcon: Icons.work_rounded,
                  label: 'My Jobs',
                  badge: newJobs),
              const AppNavItemData(
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history_rounded,
                  label: 'History'),
              const AppNavItemData(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
