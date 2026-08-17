import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  final String jobId;
  const InspectionFormScreen({super.key, required this.jobId});

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  final _defectController = TextEditingController();
  final _symptomController = TextEditingController();
  final _solutionController = TextEditingController();
  final List<String> _symptoms = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _defectController.dispose();
    _symptomController.dispose();
    _solutionController.dispose();
    super.dispose();
  }

  void _addSymptom() {
    final value = _symptomController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _symptoms.add(value);
      _symptomController.clear();
    });
  }

  Future<void> _submit() async {
    if (_defectController.text.trim().isEmpty &&
        _symptoms.isEmpty &&
        _solutionController.text.trim().isEmpty) {
      setState(() =>
          _error = 'Enter at least the defect found or symptoms observed.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.updateInspection(
        widget.jobId,
        defectFound: _defectController.text.trim(),
        symptoms: _symptoms,
        solutionType: _solutionController.text.trim(),
      );
      await repo.changeStatus(widget.jobId, 'INSPECTION_COMPLETED');
      ref.invalidate(jobDetailProvider(widget.jobId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _quickPicks(
      List<MasterOption> options, TextEditingController controller) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => ActionChip(
                  label: Text(o.label, style: const TextStyle(fontSize: 12.5)),
                  onPressed: () => setState(() => controller.text = o.label),
                  backgroundColor: AppColors.slate100,
                ))
            .toList(),
      ),
    );
  }

  Widget _symptomQuickPicks(List<MasterOption> options) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => FilterChip(
                  label: Text(o.label, style: const TextStyle(fontSize: 12.5)),
                  selected: _symptoms.contains(o.label),
                  onSelected: (v) => setState(() =>
                      v ? _symptoms.add(o.label) : _symptoms.remove(o.label)),
                  showCheckmark: false,
                  selectedColor: AppColors.primaryLight,
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final serviceId = jobAsync.valueOrNull?.serviceId;
    final diagnosticsAsync = serviceId != null
        ? ref.watch(serviceDiagnosticsProvider(serviceId))
        : null;
    final diagnostics = diagnosticsAsync?.valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Inspection & Diagnosis')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Defect Found',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          TextField(
              controller: _defectController,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'What did you find wrong with the appliance?')),
          if (diagnostics != null)
            _quickPicks(diagnostics.defects, _defectController),
          const SizedBox(height: 20),
          const Text('Symptoms Observed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _symptomController,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Unusual noise'),
                  onSubmitted: (_) => _addSymptom(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _addSymptom, icon: const Icon(Icons.add)),
            ],
          ),
          if (diagnostics != null) _symptomQuickPicks(diagnostics.symptoms),
          if (_symptoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _symptoms
                  .map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12.5)),
                        onDeleted: () => setState(() => _symptoms.remove(s)),
                        backgroundColor: AppColors.primaryLight,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Suggested Solution',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          TextField(
              controller: _solutionController,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'e.g. Compressor replacement needed')),
          if (diagnostics != null)
            _quickPicks(diagnostics.solutionTypes, _solutionController),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.urgent))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save & Complete Inspection'),
          ),
        ],
      ),
    );
  }
}
