import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_models.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../providers/push_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_header.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'notification_center_screen.dart';
import 'otp_request_screen.dart';
import 'sync_status_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Profile" — profile view,
// working-days toggle, sync status and logout. Laid out like
// citycalls-customer-mobile's Profile (dark header, grouped white cards).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _roleLabels = {
    'EMPLOYEE': 'Technician',
    'TECHNICIAN': 'Technician',
    'VENDOR_TECHNICIAN': 'Vendor Technician',
    'VENDOR_OWNER': 'Vendor Owner',
    'VENDOR_MANAGER': 'Vendor Manager',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);
    final user = ref.watch(authProvider).user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async => ref.invalidate(myEmployeeProfileProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _Header(
                name: profile.valueOrNull?.name ?? user?.name ?? '',
                mobile: profile.valueOrNull?.mobile,
                roleLabel: _roleLabels[user?.role] ?? 'Partner',
                active: profile.valueOrNull?.active,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: profile.when(
                  data: (p) => _ProfileSections(profile: p),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => UiCard(
                    child: AppErrorView(
                        error: err,
                        compact: true,
                        onRetry: () =>
                            ref.invalidate(myEmployeeProfileProvider)),
                  ),
                ),
              ),
              // Always reachable, even if the profile failed to load —
              // otherwise a load failure would leave no way to sign out.
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: _AppSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? mobile;
  final String roleLabel;
  final bool? active;
  const _Header(
      {required this.name,
      required this.mobile,
      required this.roleLabel,
      required this.active});

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return HeroHeader(
      child: Column(
        children: [
          const SizedBox(
            height: 44,
            child: Center(
              child: Text('My Profile',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [AppColors.heroLime, AppColors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2A17),
                border: Border.all(color: AppColors.heroDark, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(_initials,
                  style: const TextStyle(
                      color: AppColors.heroLime,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name.isEmpty ? 'Partner' : name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.badge_outlined, text: roleLabel),
              if (mobile != null && mobile!.isNotEmpty)
                _InfoChip(icon: Icons.phone_rounded, text: '+91 $mobile'),
              if (active != null)
                _InfoChip(
                    icon: active!
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    text: active! ? 'Active' : 'Inactive'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.heroLime),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ProfileSections extends StatelessWidget {
  final EmployeeProfile profile;
  const _ProfileSections({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UiSectionLabel('Work assignment'),
        UiCard(
          child: Column(
            children: [
              UiInfoRow(
                icon: p.isVendorTechnician
                    ? Icons.business_outlined
                    : Icons.store_outlined,
                label: p.isVendorTechnician ? 'Company' : 'Branch',
                value: p.branchName ?? 'Not assigned',
              ),
              if (p.subBranchName != null)
                UiInfoRow(
                    icon: Icons.account_tree_outlined,
                    label: 'Sub-branch',
                    value: p.subBranchName!),
              if (p.teamName != null)
                UiInfoRow(
                    icon: Icons.groups_outlined,
                    label: 'Team',
                    value: p.teamName!),
              if (!p.isVendorTechnician)
                UiInfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Capacity',
                    value: '${p.dailyCapacity} jobs / day'),
              if (p.email != null && p.email!.isNotEmpty)
                UiInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: p.email!),
            ],
          ),
        ),
        if (p.skills.isNotEmpty) ...[
          const SizedBox(height: 22),
          const UiSectionLabel('Skills'),
          UiCard(
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in p.skills)
                    UiPill(text: s, color: AppColors.green),
                ],
              ),
            ),
          ),
        ],
        if (p.certifications.isNotEmpty) ...[
          const SizedBox(height: 22),
          const UiSectionLabel('Certifications'),
          UiCard(
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in p.certifications)
                    UiPill(
                        text: c,
                        color: AppColors.info,
                        icon: Icons.verified_outlined),
                ],
              ),
            ),
          ),
        ],
        // Working days live on the Employee record — a vendor technician
        // has none, so the toggle (PATCH /employees/me/availability) would
        // always fail for them.
        if (!p.isVendorTechnician) ...[
          const SizedBox(height: 22),
          const UiSectionLabel('Working days'),
          _AvailabilitySection(availability: p.availability),
        ],
      ],
    );
  }
}

class _AppSection extends ConsumerWidget {
  const _AppSection();

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final pending = (ref.read(pendingActionsProvider).valueOrNull ?? const [])
        .where((a) => a.status == 'PENDING')
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(pending > 0
            ? 'You have $pending action(s) that have not synced yet. They will be sent the next time you log in on this phone.'
            : 'You will need an OTP to log in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.urgent,
                minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pushNotificationServiceProvider).unregisterCurrentToken();
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = (ref.watch(pendingActionsProvider).valueOrNull ?? const [])
        .where((a) => a.status != 'SYNCED')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UiSectionLabel('App'),
        UiCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuRow(
                icon: Icons.notifications_none_rounded,
                color: AppColors.indigo500,
                title: 'Notifications',
                subtitle: 'Job alerts and updates',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen())),
              ),
              const Divider(height: 1, indent: 64),
              _MenuRow(
                icon: Icons.sync_rounded,
                color: AppColors.green,
                title: 'Sync status',
                subtitle: queued > 0
                    ? '$queued action(s) waiting to sync'
                    : 'Everything is synced',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SyncStatusScreen())),
              ),
              const Divider(height: 1, indent: 64),
              _MenuRow(
                icon: Icons.logout_rounded,
                color: AppColors.urgent,
                title: 'Log out',
                titleColor: AppColors.urgent,
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('CityCalls Field • v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.faint)),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            UiIconTile(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

// Availability toggle. Optimistic: flips locally the instant a switch is
// tapped, saves via PATCH /employees/me/availability, and reverts with an
// error message if that save fails.
class _AvailabilitySection extends ConsumerStatefulWidget {
  final List<AvailabilityDay> availability;
  const _AvailabilitySection({required this.availability});

  @override
  ConsumerState<_AvailabilitySection> createState() =>
      _AvailabilitySectionState();
}

class _AvailabilitySectionState extends ConsumerState<_AvailabilitySection> {
  late List<AvailabilityDay> _days;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = _normalized(widget.availability);
  }

  @override
  void didUpdateWidget(covariant _AvailabilitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving) _days = _normalized(widget.availability);
  }

  // A newly-created Employee record has no availability configured — default
  // to "working every day" so there's something sensible to toggle off.
  List<AvailabilityDay> _normalized(List<AvailabilityDay> source) {
    final byDay = {for (final d in source) d.day: d};
    return List.generate(
        7, (day) => byDay[day] ?? AvailabilityDay(day: day, available: true));
  }

  Future<void> _toggle(int day, bool value) async {
    final previous = _days;
    setState(() {
      _days = _days
          .map((d) =>
              d.day == day ? AvailabilityDay(day: d.day, available: value) : d)
          .toList();
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(employeeRepositoryProvider).updateAvailability(_days);
      ref.invalidate(myEmployeeProfileProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _days = previous;
          _error = describeError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          for (final a in _days)
            Row(
              children: [
                Expanded(
                  child: Text(a.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              a.available ? AppColors.ink : AppColors.faint)),
                ),
                Switch(
                  value: a.available,
                  onChanged: _saving ? null : (v) => _toggle(a.day, v),
                ),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.urgent, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
