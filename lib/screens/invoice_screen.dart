import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_models.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/manish/09-vendor-app-functional-plan.md's Payment flow — once a
// job reaches PAYMENT_PENDING (or PARTIALLY_PAID), the technician bills the
// job with a real Invoice and records the payment actually collected.
// Online-only, same as estimate_form_screen.dart.
//
// Steps, in order: (1) no invoice yet → bill from the approved estimate (a
// proforma the customer accepts) or enter items by hand; (2) invoice exists
// → collect payment against it.
class InvoiceScreen extends ConsumerWidget {
  final JobDetail job;
  const InvoiceScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceForRequestProvider(job.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice & Payment')),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: AppErrorView(
              error: err,
              onRetry: () => ref.invalidate(invoiceForRequestProvider(job.id))),
        ),
        data: (invoice) => invoice == null
            ? _BillingRouter(job: job)
            : _PaymentView(job: job, invoice: invoice),
      ),
    );
  }
}

class _BillingRouter extends ConsumerWidget {
  final JobDetail job;
  const _BillingRouter({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proformaAsync = ref.watch(proformaForRequestProvider(job.id));
    return proformaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, __) => Center(
        child: AppErrorView(
            error: err,
            onRetry: () => ref.invalidate(proformaForRequestProvider(job.id))),
      ),
      data: (proforma) => proforma != null
          ? _ProformaStatusView(job: job, proforma: proforma)
          : _GenerateFromEstimateView(job: job),
    );
  }
}

// Centered "where this bill stands" card used by the estimate/proforma steps.
class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final double amount;
  final String message;
  final String? error;
  final List<Widget> actions;
  const _StatusPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.amount,
    required this.message,
    required this.actions,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        UiCard(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: UiIconTile(icon: icon, color: color, size: 60)),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 13.5, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(formatRupees(amount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.45, color: AppColors.muted)),
              const SizedBox(height: 20),
              InlineError(error),
              ...actions,
            ],
          ),
        ),
      ],
    );
  }
}

class _GenerateFromEstimateView extends ConsumerStatefulWidget {
  final JobDetail job;
  const _GenerateFromEstimateView({required this.job});

  @override
  ConsumerState<_GenerateFromEstimateView> createState() =>
      _GenerateFromEstimateViewState();
}

class _GenerateFromEstimateViewState
    extends ConsumerState<_GenerateFromEstimateView> {
  bool _generating = false;
  String? _error;
  bool _manualOverride = false;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .generateProformaInvoice(widget.job.id);
      ref.invalidate(proformaForRequestProvider(widget.job.id));
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_manualOverride) return _CreateInvoiceView(job: widget.job);

    final estimateAsync =
        ref.watch(approvedEstimateForRequestProvider(widget.job.id));
    return estimateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // No approved estimate we can read is not a dead end — the technician
      // can always bill by hand.
      error: (_, __) => _CreateInvoiceView(job: widget.job),
      data: (estimate) {
        if (estimate == null) return _CreateInvoiceView(job: widget.job);
        return _StatusPanel(
          icon: Icons.receipt_long_outlined,
          color: AppColors.green,
          title: 'Approved estimate ${estimate.number}',
          amount: estimate.total,
          message:
              'The bill will use the exact items and amount the customer already approved. They get one final confirmation in their app before it becomes the invoice.',
          error: _error,
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const ButtonSpinner(color: AppColors.muted)
                  : const Icon(Icons.send_outlined, size: 18),
              label:
                  Text(_generating ? 'Generating…' : 'Send Bill to Customer'),
            ),
            TextButton(
              onPressed: _generating
                  ? null
                  : () => setState(() => _manualOverride = true),
              child: const Text('Bill different items instead'),
            ),
          ],
        );
      },
    );
  }
}

// A proforma exists — either still waiting on the customer, or accepted and
// ready to become the real invoice.
class _ProformaStatusView extends ConsumerStatefulWidget {
  final JobDetail job;
  final ProformaInvoice proforma;
  const _ProformaStatusView({required this.job, required this.proforma});

  @override
  ConsumerState<_ProformaStatusView> createState() =>
      _ProformaStatusViewState();
}

class _ProformaStatusViewState extends ConsumerState<_ProformaStatusView> {
  bool _converting = false;
  String? _error;

  Future<void> _convert() async {
    setState(() {
      _converting = true;
      _error = null;
    });
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .convertProformaToInvoice(widget.proforma.id);
      ref.invalidate(invoiceForRequestProvider(widget.job.id));
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.proforma.status == 'ACCEPTED';
    return _StatusPanel(
      icon: accepted
          ? Icons.check_circle_outline_rounded
          : Icons.hourglass_top_rounded,
      color: accepted ? AppColors.success : AppColors.warning,
      title: 'Bill ${widget.proforma.number}',
      amount: widget.proforma.total,
      message: accepted
          ? 'The customer accepted the bill. Create the final invoice to collect payment.'
          : 'Waiting for the customer to accept the bill in their app. Ask them to open CityCalls and accept it.',
      error: _error,
      actions: [
        if (accepted)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _converting ? null : _convert,
            icon: _converting
                ? const ButtonSpinner(color: AppColors.muted)
                : const Icon(Icons.receipt_outlined, size: 18),
            label: Text(_converting ? 'Creating…' : 'Create Final Invoice'),
          )
        else
          OutlinedButton.icon(
            onPressed: () =>
                ref.invalidate(proformaForRequestProvider(widget.job.id)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check Again'),
          ),
      ],
    );
  }
}

class _CreateInvoiceView extends ConsumerStatefulWidget {
  final JobDetail job;
  const _CreateInvoiceView({required this.job});

  @override
  ConsumerState<_CreateInvoiceView> createState() => _CreateInvoiceViewState();
}

class _CreateInvoiceViewState extends ConsumerState<_CreateInvoiceView> {
  final List<InvoiceLineItem> _items = [];
  bool _submitting = false;
  String? _error;

  Future<void> _addItem() async {
    final input = await showLineItemSheet(context,
        title: 'Add line item',
        nameLabel: 'Description',
        nameHint: 'e.g. Labour charge');
    if (input == null) return;
    setState(() {
      _error = null;
      _items.add(InvoiceLineItem(
          description: input.name, qty: input.qty, unitPrice: input.unitPrice));
    });
  }

  Future<void> _create() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item before billing.');
      return;
    }
    if (widget.job.branchId.isEmpty || widget.job.customerId.isEmpty) {
      setState(() => _error =
          'This job has no branch assigned yet, so it cannot be billed from the app. Please ask the office to create the invoice.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(invoiceRepositoryProvider).createInvoice(
            customerId: widget.job.customerId,
            branchId: widget.job.branchId,
            serviceRequestId: widget.job.id,
            items: _items,
          );
      ref.invalidate(invoiceForRequestProvider(widget.job.id));
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, i) => sum + i.total);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const InfoNote(
                  'Bill this job for the labour and parts used. Once the invoice is created you can collect payment against it.'),
              const SizedBox(height: 20),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: UiEmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'No items yet',
                    message: 'Add each charge as a line item.',
                    actionLabel: 'Add Item',
                    onAction: _addItem,
                  ),
                )
              else ...[
                UiSectionLabel('${_items.length} item(s)'),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LineItemTile(
                      name: _items[i].description,
                      qty: _items[i].qty,
                      unitPrice: _items[i].unitPrice,
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (_items.isNotEmpty || _error != null)
          BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InlineError(_error),
                if (_items.isNotEmpty) TotalRow(amount: total),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _addItem,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _submitting || _items.isEmpty ? null : _create,
                        child: _submitting
                            ? const ButtonSpinner()
                            : const Text('Create Invoice'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentView extends ConsumerStatefulWidget {
  final JobDetail job;
  final Invoice invoice;
  const _PaymentView({required this.job, required this.invoice});

  @override
  ConsumerState<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<_PaymentView> {
  // What a technician can actually take at the door. GATEWAY/CREDIT exist on
  // the API (paymentMethods) but are office-side methods.
  static const _methods = {
    'CASH': (Icons.payments_outlined, 'Cash'),
    'UPI': (Icons.qr_code_2_rounded, 'UPI'),
    'CARD': (Icons.credit_card_rounded, 'Card'),
    'BANK_TRANSFER': (Icons.account_balance_outlined, 'Bank'),
    'CHEQUE': (Icons.edit_document, 'Cheque'),
  };

  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  String _method = 'CASH';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: _plain(widget.invoice.outstanding));
  }

  // After a part payment the widget rebuilds with a new invoice — reset the
  // amount to what is still owed.
  @override
  void didUpdateWidget(covariant _PaymentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice.outstanding != widget.invoice.outstanding) {
      _amountController.text = _plain(widget.invoice.outstanding);
      _referenceController.clear();
    }
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final outstanding = widget.invoice.outstanding;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0 || amount > outstanding + 0.001) {
      setState(() => _error =
          'Enter an amount between ₹1 and ${formatRupees(outstanding)}.');
      return;
    }
    final reference = _referenceController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record this payment?'),
        content: Text(
            '${formatRupees(amount)} received by ${_methods[_method]!.$2}. This cannot be undone from the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(invoiceRepositoryProvider).recordPayment(
            widget.invoice.id,
            amount: amount,
            method: _method,
            reference: reference.isEmpty ? null : reference,
          );
      ref.invalidate(invoiceForRequestProvider(widget.job.id));
      ref.invalidate(paymentsForInvoiceProvider(widget.invoice.id));
      ref.invalidate(jobDetailProvider(widget.job.id));
      ref.invalidate(allJobsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${formatRupees(amount)} payment recorded.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final settled = invoice.outstanding <= 0.001;
    final payments =
        ref.watch(paymentsForInvoiceProvider(invoice.id)).valueOrNull ??
            const <PaymentReceipt>[];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.green,
            onRefresh: () async {
              ref.invalidate(invoiceForRequestProvider(widget.job.id));
              ref.invalidate(paymentsForInvoiceProvider(invoice.id));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                UiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Invoice ${invoice.number}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.ink)),
                          ),
                          UiPill(
                              text: invoice.status.replaceAll('_', ' '),
                              color: settled
                                  ? AppColors.success
                                  : AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(settled ? 'Paid in full' : 'Amount to collect',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(
                          formatRupees(
                              settled ? invoice.total : invoice.outstanding),
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color:
                                  settled ? AppColors.success : AppColors.ink)),
                      const Divider(height: 24),
                      _kv('Invoice total', formatRupees(invoice.total)),
                      _kv('Already paid', formatRupees(invoice.amountPaid)),
                    ],
                  ),
                ),
                if (!settled) ...[
                  const SizedBox(height: 22),
                  const UiSectionLabel('Payment method'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _methods.entries)
                        ChoiceChip(
                          avatar: Icon(m.value.$1,
                              size: 16,
                              color: _method == m.key
                                  ? AppColors.green
                                  : AppColors.muted),
                          label: Text(m.value.$2),
                          selected: _method == m.key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _method = m.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const UiSectionLabel('Amount received'),
                  UiCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixIcon:
                                  Icon(Icons.currency_rupee_rounded, size: 20)),
                        ),
                        if (_method != 'CASH') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _referenceController,
                            decoration: InputDecoration(
                              labelText: _method == 'CHEQUE'
                                  ? 'Cheque number'
                                  : 'Transaction / reference ID',
                              hintText: 'Optional',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const UiSectionLabel('Payments received'),
                  UiCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        for (final p in payments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 18, color: AppColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.method.replaceAll('_', ' '),
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink)),
                                      Text(
                                          [p.number, p.reference]
                                              .whereType<String>()
                                              .join(' • '),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                Text(formatRupees(p.amount),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InlineError(_error),
              if (settled)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                )
              else
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.green),
                  onPressed: _submitting ? null : _recordPayment,
                  child: _submitting
                      ? const ButtonSpinner(color: AppColors.muted)
                      : const Text('Record Payment'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}
