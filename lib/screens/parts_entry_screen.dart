import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Parts used on this visit — queued through the offline sync batch
// (ADD_PARTS), so it can be saved without signal.
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
    final input = await showLineItemSheet(context,
        title: 'Add part',
        nameLabel: 'Part name',
        nameHint: 'e.g. Capacitor 45 MFD');
    if (input == null) return;
    setState(() {
      _error = null;
      _parts.add(PartEntry(
          name: input.name, qty: input.qty, unitPrice: input.unitPrice));
    });
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
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _parts.fold<double>(0, (sum, p) => sum + p.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Parts Used')),
      body: _parts.isEmpty
          ? UiEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No parts added yet',
              message: 'Add each part you used on this job with its price.',
              actionLabel: 'Add Part',
              onAction: _addPart,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                UiSectionLabel('${_parts.length} part(s)'),
                for (var i = 0; i < _parts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LineItemTile(
                      name: _parts[i].name,
                      qty: _parts[i].qty,
                      unitPrice: _parts[i].unitPrice,
                      onRemove: () => setState(() => _parts.removeAt(i)),
                    ),
                  ),
              ],
            ),
      // Empty: the centred "Add Part" is the only action needed.
      bottomNavigationBar: _parts.isEmpty && _error == null
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineError(_error),
                  if (_parts.isNotEmpty) TotalRow(amount: total),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _addPart,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Part'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _submitting || _parts.isEmpty ? null : _submit,
                          child: _submitting
                              ? const ButtonSpinner()
                              : const Text('Save Parts'),
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
