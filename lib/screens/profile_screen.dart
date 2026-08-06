import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_models.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../providers/push_providers.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'otp_request_screen.dart';
import 'sync_status_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Profile" — Profile view +
// Availability toggle. Notification Center is a separate screen, not yet
// built.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        // Always visible regardless of whether the profile fetch below
        // succeeds — logout was previously only reachable from inside the
        // `data:` branch of profile.when(), so any profile-load failure
        // (network hiccup, permission issue, etc.) left the technician with
        // no way to sign out at all. Fixed as a real bug, not a style tweak.
        actions: [
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout, color: AppColors.urgent),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: profile.when(
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myEmployeeProfileProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])),
                      child: Center(child: Text(_initials(p.name), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(height: 14),
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    if (p.mobile != null) ...[
                      const SizedBox(height: 3),
                      Text(p.mobile!, style: TextStyle(color: secondaryTextColor(context), fontSize: 13)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: p.active ? AppColors.success.withValues(alpha: 0.1) : AppColors.slate500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(p.active ? 'Active' : 'Inactive', style: TextStyle(color: p.active ? AppColors.success : AppColors.slate500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Work Assignment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.store_outlined, label: 'Branch', value: p.branchName ?? 'Not assigned'),
                    if (p.subBranchName != null) ...[const SizedBox(height: 10), _InfoRow(icon: Icons.account_tree_outlined, label: 'Sub-Branch', value: p.subBranchName!)],
                    if (p.teamName != null) ...[const SizedBox(height: 10), _InfoRow(icon: Icons.groups_outlined, label: 'Team', value: p.teamName!)],
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.event_available_outlined, label: 'Daily Job Capacity', value: '${p.dailyCapacity} jobs/day'),
                  ],
                ),
              ),
              if (p.skills.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Skills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.skills
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                                  child: Text(s, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              if (p.certifications.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Certifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.certifications
                            .map((c) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.verified_outlined, size: 13, color: AppColors.success),
                                    const SizedBox(width: 4),
                                    Text(c, style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                                  ]),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _AvailabilitySection(availability: p.availability),
              const SizedBox(height: 16),
              const _AppearanceSection(),
              const SizedBox(height: 16),
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.sync, color: AppColors.primary),
                  title: const Text('Sync Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Offline actions waiting to sync', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.slate400),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.urgent),
                label: const Text('Log Out', style: TextStyle(color: AppColors.urgent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.urgent)),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: AppColors.slate400),
                const SizedBox(height: 12),
                Text('Could not load profile: $err', style: const TextStyle(color: AppColors.slate500), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.urgent),
                  label: const Text('Log Out', style: TextStyle(color: AppColors.urgent)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.urgent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(pushNotificationServiceProvider).unregisterCurrentToken();
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OtpRequestScreen()), (route) => false);
    }
  }
}

// Per docs/rohit/06-vendor-app-screen-list.md "Profile" — Availability
// toggle. Optimistic: flips locally the instant a switch is tapped, saves in
// the background via PATCH /employees/me/availability, and reverts with an
// error message if that save fails — never leaves the switch silently out
// of sync with what's actually persisted.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(themeModeProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.brightness_6_outlined, size: 19),
              SizedBox(width: 8),
              Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Choose how CityCalls Field looks on this device.', style: TextStyle(fontSize: 11.5, color: secondaryTextColor(context))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined, size: 17), label: Text('System')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 17), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 17), label: Text('Dark')),
              ],
              selected: {selectedMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref.read(themeModeProvider.notifier).setMode(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySection extends ConsumerStatefulWidget {
  final List<AvailabilityDay> availability;
  const _AvailabilitySection({required this.availability});

  @override
  ConsumerState<_AvailabilitySection> createState() => _AvailabilitySectionState();
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

  // A newly-created Employee record has no availability configured at all —
  // defaults to "working every day" so the technician has something sensible
  // to toggle off, rather than an empty section implying nothing is set up.
  List<AvailabilityDay> _normalized(List<AvailabilityDay> source) {
    if (source.isEmpty) {
      return List.generate(7, (day) => AvailabilityDay(day: day, available: true));
    }
    final byDay = {for (final d in source) d.day: d};
    return List.generate(7, (day) => byDay[day] ?? AvailabilityDay(day: day, available: true));
  }

  Future<void> _toggle(int day, bool value) async {
    final previous = _days;
    setState(() {
      _days = _days.map((d) => d.day == day ? AvailabilityDay(day: d.day, available: value) : d).toList();
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(employeeRepositoryProvider).updateAvailability(_days);
      ref.invalidate(myEmployeeProfileProvider);
    } catch (e) {
      setState(() {
        _days = previous;
        _error = 'Could not save — try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Working Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              if (_saving) const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: _days
                .map((a) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(a.label, style: TextStyle(fontSize: 13, color: a.available ? Theme.of(context).colorScheme.onSurface : secondaryTextColor(context)))),
                          Switch(
                            value: a.available,
                            activeTrackColor: AppColors.primary,
                            onChanged: _saving ? null : (value) => _toggle(a.day, value),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: AppColors.urgent, fontSize: 11.5))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: secondaryTextColor(context)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: secondaryTextColor(context))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
