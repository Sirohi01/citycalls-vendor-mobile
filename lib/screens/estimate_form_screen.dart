import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/estimate_models.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

// Per docs/manish/09-vendor-app-functional-plan.md's Estimate flow — after
// inspection, a technician can draft an estimate for extra parts/labour and
// share it with the customer for approval, instead of jumping straight to
// Start Work. Online-only (see estimate_repository.dart) — not part of the
// offline sync-batch queue.
class EstimateFormScreen extends ConsumerStatefulWidget {
  final JobDetail job;
  const EstimateFormScreen({super.key, required this.job});

  @override
  ConsumerState<EstimateFormScreen> createState() => _EstimateFormScreenState();
}

class _EstimateFormScreenState extends ConsumerState<EstimateFormScreen> {
  final List<EstimateLineItem> _items = [];
  bool _submitting = false;
  String? _error;

  Future<void> _addItem() async {
    final item = await showModalBottomSheet<EstimateLineItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLineItemSheet(),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _createAndShare() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item before sharing.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(estimateRepositoryProvider);
      final estimate = await repo.createEstimate(
        customerId: widget.job.customerId,
        branchId: widget.job.branchId,
        serviceRequestId: widget.job.id,
        items: _items,
      );
      await repo.shareEstimate(estimate.id);
      ref.invalidate(jobDetailProvider(widget.job.id));
      ref.invalidate(myJobsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to create/share estimate: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, i) => sum + i.total);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Create Estimate')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Add parts/labour needed beyond the base visit. The customer will be asked to approve this before you continue.',
              style: TextStyle(fontSize: 12.5, color: secondaryTextColor(context)),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: secondaryTextColor(context)),
                        const SizedBox(height: 12),
                        Text('No line items added yet.', style: TextStyle(color: secondaryTextColor(context))),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('${item.qty} × ₹${item.unitPrice.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 12, color: secondaryTextColor(context))),
                                ],
                              ),
                            ),
                            Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.urgent),
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
              child: Text(_error!, style: const TextStyle(color: AppColors.urgent)),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
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
                        Text('Total', style: TextStyle(color: secondaryTextColor(context))),
                        Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        onPressed: _submitting ? null : _createAndShare,
                        child: _submitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Share with Customer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLineItemSheet extends StatefulWidget {
  const _AddLineItemSheet();

  @override
  State<_AddLineItemSheet> createState() => _AddLineItemSheetState();
}

class _AddLineItemSheetState extends State<_AddLineItemSheet> {
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
    if (description.isEmpty || qty == null || qty <= 0 || price == null || price < 0) {
      setState(() => _error = 'Enter a valid description, quantity, and price.');
      return;
    }
    Navigator.of(context).pop(EstimateLineItem(description: description, qty: qty, unitPrice: price));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                decoration: BoxDecoration(color: secondaryTextColor(context).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Add Line Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (e.g. Compressor replacement)'),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Unit price (₹)'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: AppColors.urgent, fontSize: 12.5)),
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
