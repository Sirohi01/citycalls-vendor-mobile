import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

class PartsEntryScreen extends ConsumerStatefulWidget {
  final String jobId;
  const PartsEntryScreen({super.key, required this.jobId});

  @override
  ConsumerState<PartsEntryScreen> createState() => _PartsEntryScreenState();
}

class _PartsEntryScreenState extends ConsumerState<PartsEntryScreen> {
  final List<PartEntry> _parts = [];
  bool _submitting = false;
  String? _error;

  Future<void> _addPart() async {
    final entry = await showModalBottomSheet<PartEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddPartSheet(),
    );
    if (entry != null) setState(() => _parts.add(entry));
  }

  Future<void> _submit() async {
    if (_parts.isEmpty) {
      setState(() => _error = 'Add at least one part before saving.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(jobRepositoryProvider).addParts(widget.jobId, _parts);
      ref.invalidate(jobDetailProvider(widget.jobId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _parts.fold<double>(0, (sum, p) => sum + p.total);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Parts Used')),
      body: Column(
        children: [
          Expanded(
            child: _parts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: secondaryTextColor(context)),
                        const SizedBox(height: 12),
                        Text('No parts added yet.',
                            style:
                                TextStyle(color: secondaryTextColor(context))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _parts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final part = _parts[i];
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(part.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${part.qty} × ₹${part.unitPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryTextColor(context))),
                                ],
                              ),
                            ),
                            Text('₹${part.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppColors.urgent),
                              onPressed: () =>
                                  setState(() => _parts.removeAt(i)),
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
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.urgent))),
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
                if (_parts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style:
                                TextStyle(color: secondaryTextColor(context))),
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
                        onPressed: _addPart,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Part'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Parts'),
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

class _AddPartSheet extends StatefulWidget {
  const _AddPartSheet();

  @override
  State<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends State<_AddPartSheet> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty || qty == null || qty <= 0 || price == null || price < 0) {
      setState(() => _error = 'Enter a valid name, quantity, and price.');
      return;
    }
    Navigator.of(context)
        .pop(PartEntry(name: name, qty: qty, unitPrice: price));
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
            const Text('Add Part',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Part name'),
                textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Unit price (₹)'))),
              ],
            ),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.urgent, fontSize: 12.5))),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
