import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Read-only — the backend blocks vendor-role actors from creating/approving
// their own invoices or marking their own payouts paid (a real self-billing
// risk this deliberately closes, see vendorFinance.controller.ts's
// assertNotVendorSelfService). Admin-web's Vendor detail page owns those
// write actions.
class VendorPayoutsScreen extends ConsumerWidget {
  const VendorPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(vendorInvoicesProvider);
    final payoutsAsync = ref.watch(vendorPayoutsProvider);
    final payouts = payoutsAsync.valueOrNull ?? const <VendorPayout>[];
    final received = payouts
        .where((p) => p.status == 'PAID')
        .fold<double>(0, (s, p) => s + p.amount);
    final pending = payouts
        .where((p) => p.status != 'PAID' && p.status != 'FAILED')
        .fold<double>(0, (s, p) => s + p.amount);

    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: () async {
        ref.invalidate(vendorInvoicesProvider);
        ref.invalidate(vendorPayoutsProvider);
        await ref
            .read(vendorPayoutsProvider.future)
            .catchError((_) => <VendorPayout>[]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomNavClearance(context)),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                    label: 'Received',
                    amount: payoutsAsync.hasValue ? received : null,
                    color: AppColors.success,
                    icon: Icons.account_balance_wallet_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                    label: 'Pending',
                    amount: payoutsAsync.hasValue ? pending : null,
                    color: AppColors.warning,
                    icon: Icons.hourglass_top_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Payouts'),
          payoutsAsync.when(
            loading: () => const _Loading(),
            error: (err, __) => UiCard(
              child: AppErrorView(
                  error: err,
                  compact: true,
                  onRetry: () => ref.invalidate(vendorPayoutsProvider)),
            ),
            data: (items) => items.isEmpty
                ? const _EmptyCard(
                    icon: Icons.payments_outlined, text: 'No payouts yet')
                : Column(
                    children: [
                      for (final p in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PayoutCard(payout: p),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Invoices'),
          invoicesAsync.when(
            loading: () => const _Loading(),
            error: (err, __) => UiCard(
              child: AppErrorView(
                  error: err,
                  compact: true,
                  onRetry: () => ref.invalidate(vendorInvoicesProvider)),
            ),
            data: (items) => items.isEmpty
                ? const _EmptyCard(
                    icon: Icons.receipt_long_outlined, text: 'No invoices yet')
                : Column(
                    children: [
                      for (final i in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InvoiceCard(invoice: i),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()));
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.faint),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double? amount;
  final Color color;
  final IconData icon;
  const _SummaryTile(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiIconTile(icon: icon, color: color, size: 36),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount == null ? '—' : formatRupees(amount!),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  if (status == 'PAID' || status == 'APPROVED') return AppColors.success;
  if (status == 'DISPUTED' || status == 'FAILED' || status == 'REJECTED') {
    return AppColors.urgent;
  }
  return AppColors.warning;
}

class _PayoutCard extends StatelessWidget {
  final VendorPayout payout;
  const _PayoutCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatRupees(payout.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                    [payout.number, payout.reference]
                        .whereType<String>()
                        .join(' • '),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          UiPill(
              text: payout.status.replaceAll('_', ' '),
              color: _statusColor(payout.status)),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final VendorInvoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              Text(value,
                  style: TextStyle(
                      fontSize: strong ? 15 : 13.5,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.ink)),
            ],
          ),
        );

    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(invoice.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.ink)),
              ),
              UiPill(
                  text: invoice.status.replaceAll('_', ' '),
                  color: _statusColor(invoice.status)),
            ],
          ),
          const SizedBox(height: 10),
          row('Job value', formatRupees(invoice.grossAmount)),
          row('CityCalls commission',
              '− ${formatRupees(invoice.commissionAmount)}'),
          const Divider(height: 14),
          row('You receive', formatRupees(invoice.netAmount), strong: true),
        ],
      ),
    );
  }
}
