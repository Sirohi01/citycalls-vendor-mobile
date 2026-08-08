import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';

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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(vendorInvoicesProvider);
        ref.invalidate(vendorPayoutsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invoices', style: TextStyle(fontWeight: FontWeight.w700, color: secondaryTextColor(context))),
          const SizedBox(height: 10),
          invoicesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (err, __) => Text('Could not load invoices: $err', style: const TextStyle(color: AppColors.urgent)),
            data: (invoices) => invoices.isEmpty
                ? Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('No invoices yet.', style: TextStyle(color: secondaryTextColor(context))))
                : Column(children: invoices.map((i) => _InvoiceCard(invoice: i)).toList()),
          ),
          const SizedBox(height: 24),
          Text('Payouts', style: TextStyle(fontWeight: FontWeight.w700, color: secondaryTextColor(context))),
          const SizedBox(height: 10),
          payoutsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (err, __) => Text('Could not load payouts: $err', style: const TextStyle(color: AppColors.urgent)),
            data: (payouts) => payouts.isEmpty
                ? Text('No payouts yet.', style: TextStyle(color: secondaryTextColor(context)))
                : Column(children: payouts.map((p) => _PayoutCard(payout: p)).toList()),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                _StatusPill(status: invoice.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Gross ₹${invoice.grossAmount.toStringAsFixed(0)} − commission ₹${invoice.commissionAmount.toStringAsFixed(0)} = Net ₹${invoice.netAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: secondaryTextColor(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final VendorPayout payout;
  const _PayoutCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payout.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${payout.amount.toStringAsFixed(0)}${payout.reference != null ? ' · ${payout.reference}' : ''}',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor(context)),
                  ),
                ],
              ),
            ),
            _StatusPill(status: payout.status),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'PAID';
    final isBad = status == 'DISPUTED' || status == 'FAILED';
    final color = isPaid ? Colors.green : (isBad ? AppColors.urgent : AppColors.gold400);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
