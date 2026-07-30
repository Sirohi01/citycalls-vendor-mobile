import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Work Progress
// log, Parts Entry (parts UI deferred — see job_repository.dart's addParts
// for when it's needed), Before/After Image Capture. Saves via
// PATCH .../visits/work — images/notes/labour accumulate server-side
// (append, not replace), so this screen can be reopened multiple times
// across a multi-visit job.
class WorkProgressScreen extends ConsumerStatefulWidget {
  final String jobId;
  const WorkProgressScreen({super.key, required this.jobId});

  @override
  ConsumerState<WorkProgressScreen> createState() => _WorkProgressScreenState();
}

class _WorkProgressScreenState extends ConsumerState<WorkProgressScreen> {
  final _notesController = TextEditingController();
  final _labourController = TextEditingController();
  final List<File> _beforePhotos = [];
  final List<File> _afterPhotos = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    _labourController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(List<File> target) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => target.add(File(picked.path)));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);

      final beforeUrls = <String>[];
      for (final f in _beforePhotos) {
        beforeUrls.add(await repo.uploadJobImage(widget.jobId, f, category: 'BEFORE_SERVICE_IMAGE'));
      }
      final afterUrls = <String>[];
      for (final f in _afterPhotos) {
        afterUrls.add(await repo.uploadJobImage(widget.jobId, f, category: 'AFTER_SERVICE_IMAGE'));
      }

      final labour = double.tryParse(_labourController.text.trim());
      await repo.updateWork(
        widget.jobId,
        labourCharge: labour,
        workNotes: _notesController.text.trim(),
        beforeImages: beforeUrls.isEmpty ? null : beforeUrls,
        afterImages: afterUrls.isEmpty ? null : afterUrls,
      );

      final current = await ref.read(jobDetailProvider(widget.jobId).future);
      if (current.status == 'WORK_STARTED') {
        await repo.changeStatus(widget.jobId, 'WORK_IN_PROGRESS');
      }

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
    return Scaffold(
      backgroundColor: AppColors.slate100,
      appBar: AppBar(title: const Text('Work Progress')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Work Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          TextField(controller: _notesController, maxLines: 4, decoration: const InputDecoration(hintText: 'What work was carried out?')),
          const SizedBox(height: 20),
          const Text('Labour Charge (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          TextField(controller: _labourController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Optional')),
          const SizedBox(height: 20),
          _PhotoSection(title: 'Before Photos', photos: _beforePhotos, onAdd: () => _pickPhoto(_beforePhotos), onRemove: (f) => setState(() => _beforePhotos.remove(f))),
          const SizedBox(height: 20),
          _PhotoSection(title: 'After Photos', photos: _afterPhotos, onAdd: () => _pickPhoto(_afterPhotos), onRemove: (f) => setState(() => _afterPhotos.remove(f))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: AppColors.urgent))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Progress'),
          ),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<File> onRemove;
  const _PhotoSection({required this.title, required this.photos, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...photos.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(f, width: 84, height: 84, fit: BoxFit.cover)),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => onRemove(f),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.slate300), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppColors.slate500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
