import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// Backs the Dashboard screen's live-location card (Rapido/Uber-style "you are
// here" map). Foreground-only — no background service, matches the docs'
// event-based (not continuous background) position on location granularity.
// A StreamProvider so the map marker updates as the technician moves, without
// the screen having to manage a subscription itself.
enum LocationPermissionState { unknown, granted, denied, deniedForever, serviceDisabled }

final locationPermissionProvider = FutureProvider<LocationPermissionState>((ref) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return LocationPermissionState.serviceDisabled;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) return LocationPermissionState.deniedForever;
  if (permission == LocationPermission.denied) return LocationPermissionState.denied;
  return LocationPermissionState.granted;
});

final currentPositionStreamProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
  );
});
