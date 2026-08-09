import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_models.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

// Per docs/manish/09-vendor-app-functional-plan.md's Payment flow — once a
// job reaches PAYMENT_PENDING (or PARTIALLY_PAID, if a partial payment was
// already taken), the technician bills the job with a real Invoice and
// records the actual payment collected, instead of just flipping the
// service request's status. Online-only, same as estimate_form_screen.dart.
class InvoiceScreen extends ConsumerWidget {
  final JobDetail job;
  const InvoiceScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceForRequestProvider(job.id));
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Invoice & Payment')),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
            child: Text('Could not load invoice: $err',
                style: const TextStyle(color: AppColors.urgent))),
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
          child: Text('Could not load billing status: $err',
              style: const TextStyle(color: AppColors.urgent))),
      data: (proforma) {
        if (proforma != null) {
          return _ProformaStatusView(job: job, proforma: proforma);
        }
        return _GenerateFromEstimateView(job: job);
      },
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
      setState(() => _error = 'Failed to generate bill: $e');
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
      error: (err, __) => Center(
          child: Text('Could not check for an approved estimate: $err',
              style: const TextStyle(color: AppColors.urgent))),
      data: (estimate) {
        if (estimate == null) return _CreateInvoiceView(job: widget.job);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Approved estimate ${estimate.number}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text('₹${estimate.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const SizedBox(height: 8),
                const Text(
                  'The bill will use the exact items and amount the customer already approved. They will get one final confirmation to accept it before it becomes the invoice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate500, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.urgent, fontSize: 12.5))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(_generating
                        ? 'Generating...'
                        : 'Generate Bill for Customer'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _manualOverride = true),
                  child: const Text('Bill this differently instead'),
                ),
              ],
            ),
          ),
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
      setState(() => _error = 'Failed to create the final invoice: $e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.proforma.status == 'ACCEPTED';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                accepted
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top_outlined,
                size: 48,
                color: accepted ? AppColors.success : AppColors.warning),
            const SizedBox(height: 16),
            Text(widget.proforma.number,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text('₹${widget.proforma.total.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              accepted
                  ? 'The customer accepted the bill. Create the final invoice below.'
                  : 'Waiting for the customer to accept the bill in their app.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate500, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.urgent, fontSize: 12.5))),
            if (accepted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _converting ? null : _convert,
                  icon: _converting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.receipt_outlined, size: 18),
                  label: Text(
                      _converting ? 'Creating...' : 'Create Final Invoice'),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(proformaForRequestProvider(widget.job.id)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check Again'),
              ),
          ],
        ),
      ),
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
    final item = await showModalBottomSheet<InvoiceLineItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInvoiceLineItemSheet(),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _create() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item before billing.');
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
      setState(() => _error = 'Failed to create invoice: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, i) => sum + i.total);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Bill this job for labour and parts used. Once created, you can collect payment against it.',
            style:
                TextStyle(fontSize: 12.5, color: secondaryTextColor(context)),
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 48, color: secondaryTextColor(context)),
                      const SizedBox(height: 12),
                      Text('No line items added yet.',
                          style: TextStyle(color: secondaryTextColor(context))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.description,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                    '${item.qty} × ₹${item.unitPrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor(context))),
                              ],
                            ),
                          ),
                          Text('₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.urgent),
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Text(_error!, style: const TextStyle(color: AppColors.urgent)),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: TextStyle(color: secondaryTextColor(context))),
                      Text('₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _create,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
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
  late double _amount;
  String _method = 'CASH';
  final _referenceController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = widget.invoice.outstanding;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (_amount <= 0 || _amount > widget.invoice.outstanding) {
      setState(() => _error =
          'Amount must be between ₹0.01 and ₹${widget.invoice.outstanding.toStringAsFixed(0)}.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(invoiceRepositoryProvider).recordPayment(
            widget.invoice.id,
            amount: _amount,
            method: _method,
            reference: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
          );
      ref.invalidate(invoiceForRequestProvider(widget.job.id));
      ref.invalidate(jobDetailProvider(widget.job.id));
      ref.invalidate(myJobsProvider);
    } catch (e) {
      setState(() => _error = 'Failed to record payment: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final settled = invoice.outstanding <= 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(invoice.number,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(invoice.status.replaceAll('_', ' '),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: settled ? Colors.green : AppColors.gold400)),
                ],
              ),
              const SizedBox(height: 12),
              _kv(context, 'Total', '₹${invoice.total.toStringAsFixed(0)}'),
              _kv(context, 'Paid', '₹${invoice.amountPaid.toStringAsFixed(0)}'),
              _kv(context, 'Outstanding',
                  '₹${invoice.outstanding.toStringAsFixed(0)}',
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (settled)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Fully paid. Nothing more to collect on this job.')),
              ],
            ),
          )
        else ...[
          Text('Record Payment',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: secondaryTextColor(context))),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _amount.toStringAsFixed(0),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Amount (₹)'),
                        onChanged: (v) =>
                            setState(() => _amount = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _method,
                        decoration: const InputDecoration(labelText: 'Method'),
                        items: paymentMethods
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(m.replaceAll('_', ' '))))
                            .toList(),
                        onChanged: (v) => setState(() => _method = v ?? 'CASH'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                      hintText: 'Transaction ID / cheque no.'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.urgent, fontSize: 12.5)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _recordPayment,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Record Payment (₹${_amount.toStringAsFixed(0)})'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _kv(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryTextColor(context))),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}

class _AddInvoiceLineItemSheet extends StatefulWidget {
  const _AddInvoiceLineItemSheet();

  @override
  State<_AddInvoiceLineItemSheet> createState() =>
      _AddInvoiceLineItemSheetState();
}

class _AddInvoiceLineItemSheetState extends State<_AddInvoiceLineItemSheet> {
  final _descController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final description = _descController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (description.isEmpty ||
        qty == null ||
        qty <= 0 ||
        price == null ||
        price < 0) {
      setState(
          () => _error = 'Enter a valid description, quantity, and price.');
      return;
    }
    Navigator.of(context).pop(
        InvoiceLineItem(description: description, qty: qty, unitPrice: price));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: secondaryTextColor(context).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Add Line Item',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                  labelText: 'Description (e.g. Labour charge)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Unit price (₹)'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.urgent, fontSize: 12.5)),
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
