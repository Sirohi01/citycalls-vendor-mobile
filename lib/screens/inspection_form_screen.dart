import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Inspection & diagnosis — what the technician found. Quick-pick chips come
// from the service's own Master lists (GET /services/:id/diagnostics); free
// text is always allowed. Saving moves the job to INSPECTION_COMPLETED.
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
      if (!_symptoms.contains(value)) _symptoms.add(value);
      _symptomController.clear();
    });
  }

  Future<void> _submit() async {
    _addSymptom();
    if (_defectController.text.trim().isEmpty && _symptoms.isEmpty) {
      setState(() =>
          _error = 'Enter the defect you found, or at least one symptom.');
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
      ref.invalidate(allJobsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Tapping a chip fills the field (single-choice suggestions).
  Widget _quickPicks(
      List<MasterOption> options, TextEditingController controller) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o.label),
              selected: controller.text.trim() == o.label,
              showCheckmark: false,
              onSelected: (_) => setState(() => controller.text = o.label),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceId =
        ref.watch(jobDetailProvider(widget.jobId)).valueOrNull?.serviceId;
    final diagnostics = serviceId == null
        ? null
        : ref.watch(serviceDiagnosticsProvider(serviceId)).valueOrNull;
    // Master symptoms plus anything typed by hand, as one multi-select set.
    final symptomOptions = <String>{
      ...?diagnostics?.symptoms.map((o) => o.label),
      ..._symptoms,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection & Diagnosis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const UiSectionLabel('Defect found'),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _defectController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: 'What did you find wrong with the appliance?'),
                ),
                if (diagnostics != null)
                  _quickPicks(diagnostics.defects, _defectController),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Symptoms observed'),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (symptomOptions.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in symptomOptions)
                        FilterChip(
                          label: Text(s),
                          selected: _symptoms.contains(s),
                          showCheckmark: false,
                          onSelected: (v) => setState(
                              () => v ? _symptoms.add(s) : _symptoms.remove(s)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symptomController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            hintText: 'Add another, e.g. Unusual noise'),
                        onSubmitted: (_) => _addSymptom(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addSymptom,
                      tooltip: 'Add symptom',
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.green,
                          minimumSize: const Size(48, 48)),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Suggested solution'),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _solutionController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: 'e.g. Compressor replacement needed'),
                ),
                if (diagnostics != null)
                  _quickPicks(diagnostics.solutionTypes, _solutionController),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InlineError(_error),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const ButtonSpinner()
                  : const Text('Save & Complete Inspection'),
            ),
          ],
        ),
      ),
    );
  }
}
