import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Work Progress
// log and Before/After image capture. Notes/labour/images accumulate
// server-side (append, not replace), so this screen can be reopened several
// times across a multi-visit job.
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
  // Photos already uploaded in a previous attempt, keyed by local path, so a
  // retry after a failure doesn't upload (and attach) them a second time.
  final Map<String, String> _uploaded = {};
  bool _submitting = false;
  String? _progress;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    _labourController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(List<File> target) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Downscaled so a photo uploads quickly on mobile data.
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 75, maxWidth: 1600);
      if (picked != null && mounted) {
        setState(() => target.add(File(picked.path)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open the camera or gallery. Check the app permissions.');
      }
    }
  }

  Future<List<String>> _upload(List<File> files, String category) async {
    final repo = ref.read(jobRepositoryProvider);
    final urls = <String>[];
    for (final f in files) {
      urls.add(_uploaded[f.path] ??=
          await repo.uploadJobImage(widget.jobId, f, category: category));
    }
    return urls;
  }

  Future<void> _submit() async {
    final labourText = _labourController.text.trim();
    final labour = labourText.isEmpty ? null : double.tryParse(labourText);
    if (labourText.isNotEmpty && (labour == null || labour < 0)) {
      setState(() => _error = 'Enter a valid labour charge.');
      return;
    }
    if (_notesController.text.trim().isEmpty &&
        labour == null &&
        _beforePhotos.isEmpty &&
        _afterPhotos.isEmpty) {
      setState(() => _error = 'Add notes, a labour charge or a photo first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      final photoCount = _beforePhotos.length + _afterPhotos.length;
      if (photoCount > 0) {
        setState(() => _progress = 'Uploading $photoCount photo(s)…');
      }
      final beforeUrls = await _upload(_beforePhotos, 'BEFORE_SERVICE_IMAGE');
      final afterUrls = await _upload(_afterPhotos, 'AFTER_SERVICE_IMAGE');

      if (mounted) setState(() => _progress = 'Saving…');
      await repo.updateWork(
        widget.jobId,
        labourCharge: labour,
        workNotes: _notesController.text.trim(),
        beforeImages: beforeUrls.isEmpty ? null : beforeUrls,
        afterImages: afterUrls.isEmpty ? null : afterUrls,
      );

      // Logging work is what moves WORK_STARTED on to WORK_IN_PROGRESS. The
      // status read is best-effort: offline, the update above is already
      // queued and the hop can happen from Job Detail later.
      try {
        final current = await repo.getJob(widget.jobId);
        if (current.status == 'WORK_STARTED') {
          await repo.changeStatus(widget.jobId, 'WORK_IN_PROGRESS');
        }
      } catch (_) {}

      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(allJobsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const UiSectionLabel('Work notes'),
          UiCard(
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'What work was carried out?'),
            ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Labour charge (optional)'),
          UiCard(
            child: TextField(
              controller: _labourController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                  hintText: '0'),
            ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Before photos'),
          _PhotoStrip(
            photos: _beforePhotos,
            enabled: !_submitting,
            onAdd: () => _pickPhoto(_beforePhotos),
            onRemove: (f) => setState(() => _beforePhotos.remove(f)),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('After photos'),
          _PhotoStrip(
            photos: _afterPhotos,
            enabled: !_submitting,
            onAdd: () => _pickPhoto(_afterPhotos),
            onRemove: (f) => setState(() => _afterPhotos.remove(f)),
          ),
          const SizedBox(height: 12),
          const Text('Photos need an internet connection to upload.',
              style: TextStyle(fontSize: 12, color: AppColors.faint)),
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
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ButtonSpinner(color: AppColors.muted),
                        const SizedBox(width: 10),
                        Text(_progress ?? 'Saving…'),
                      ],
                    )
                  : const Text('Save Progress'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<File> photos;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<File> onRemove;
  const _PhotoStrip(
      {required this.photos,
      required this.enabled,
      required this.onAdd,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in photos)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        Image.file(f, width: 92, height: 92, fit: BoxFit.cover),
                  ),
                  if (enabled)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(f),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onAdd : null,
              child: const SizedBox(
                width: 92,
                height: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.green),
                    SizedBox(height: 6),
                    Text('Add photo',
                        style:
                            TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
