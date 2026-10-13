import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/job_repository.dart';
import 'job_providers.dart';

// Sends the technician's position to every job they're currently travelling
// to (TECHNICIAN_EN_ROUTE), so the customer app's live map moves. This used
// to live inside JobDetailScreen, which meant pings stopped the moment the
// technician left that screen; it now runs for as long as MainShell is up,
// whatever tab or screen is showing.
//
// Still foreground-only: when the OS suspends the app, pings pause until it
// is reopened (a true background tracker needs a foreground service).
class TransitTracker {
  static const _interval = Duration(seconds: 20);
  final JobRepository _repo;
  Timer? _timer;
  Set<String> _jobIds = {};

  TransitTracker(this._repo);

  void update(Iterable<String> enRouteJobIds) {
    final next = enRouteJobIds.toSet();
    final started = next.difference(_jobIds).isNotEmpty;
    _jobIds = next;
    if (_jobIds.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_interval, (_) => _pingAll());
    if (started) _pingAll();
  }

  Future<void> _pingAll() async {
    if (_jobIds.isEmpty) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      for (final id in _jobIds) {
        await _repo.sendLocationPing(id, position.latitude, position.longitude);
      }
    } catch (_) {
      // Best-effort — a missed ping is simply replaced by the next one.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

final transitTrackerProvider = Provider<TransitTracker>((ref) {
  final tracker = TransitTracker(ref.watch(jobRepositoryProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});
