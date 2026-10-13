import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/estimate_models.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

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
  // Set once the estimate exists server-side. If sharing then fails, a
  // retry only re-shares it — it must not create a second estimate.
  String? _createdEstimateId;

  Future<void> _addItem() async {
    final input = await showLineItemSheet(context,
        title: 'Add line item',
        nameLabel: 'Description',
        nameHint: 'e.g. Compressor replacement');
    if (input == null) return;
    setState(() {
      _error = null;
      _items.add(EstimateLineItem(
          description: input.name, qty: input.qty, unitPrice: input.unitPrice));
    });
  }

  Future<void> _createAndShare() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item before sharing.');
      return;
    }
    if (widget.job.branchId.isEmpty || widget.job.customerId.isEmpty) {
      setState(() => _error =
          'This job has no branch assigned yet, so an estimate cannot be created from the app. Please ask the office to add it.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(estimateRepositoryProvider);
      _createdEstimateId ??= (await repo.createEstimate(
        customerId: widget.job.customerId,
        branchId: widget.job.branchId,
        serviceRequestId: widget.job.id,
        items: _items,
      ))
          .id;
      await repo.shareEstimate(_createdEstimateId!);
      ref.invalidate(jobDetailProvider(widget.job.id));
      ref.invalidate(allJobsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Estimate sent to the customer for approval.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, i) => sum + i.total);
    // Once created, the items are fixed server-side — only sharing remains.
    final locked = _createdEstimateId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Estimate')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const InfoNote(
              'Add the parts and labour needed. The customer will be asked to approve this before you start work.'),
          const SizedBox(height: 20),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: UiEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No items yet',
                message: 'Add each part or labour charge as a line item.',
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
                  onRemove:
                      locked ? null : () => setState(() => _items.removeAt(i)),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: _items.isEmpty && _error == null
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineError(_error),
                  if (_items.isNotEmpty) TotalRow(amount: total),
                  Row(
                    children: [
                      if (!locked) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _addItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Item'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting || _items.isEmpty
                              ? null
                              : _createAndShare,
                          child: _submitting
                              ? const ButtonSpinner()
                              : Text(
                                  locked ? 'Send Again' : 'Send to Customer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
