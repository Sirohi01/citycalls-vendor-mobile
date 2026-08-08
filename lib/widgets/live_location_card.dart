import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../providers/location_providers.dart';
import '../theme/app_theme.dart';

// Rapido/Uber-style "you are here" card for the Dashboard — a live map
// centered on the technician's current GPS position with a pulsing marker.
// OpenStreetMap tiles (flutter_map), not Google Maps — no API key or Google
// Cloud billing setup required, so this works immediately.
class LiveLocationCard extends ConsumerStatefulWidget {
  const LiveLocationCard({super.key});

  @override
  ConsumerState<LiveLocationCard> createState() => _LiveLocationCardState();
}

class _LiveLocationCardState extends ConsumerState<LiveLocationCard> {
  final _mapController = MapController();
  bool _centeredOnce = false;

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(locationPermissionProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: permission.when(
          loading: () => const _LocationPlaceholder(child: CircularProgressIndicator(strokeWidth: 2.4)),
          error: (_, __) => const _LocationPlaceholder(
            icon: Icons.location_off_outlined,
            text: 'Could not access location',
          ),
          data: (state) {
            switch (state) {
              case LocationPermissionState.granted:
                return _MapView(mapController: _mapController, onFirstFix: () => _centeredOnce = true, centeredOnce: _centeredOnce);
              case LocationPermissionState.serviceDisabled:
                return const _LocationPlaceholder(
                  icon: Icons.location_disabled_outlined,
                  text: 'Turn on device location to see it here',
                );
              case LocationPermissionState.deniedForever:
                return const _LocationPlaceholder(
                  icon: Icons.location_off_outlined,
                  text: 'Location permission blocked — enable it from app settings',
                );
              case LocationPermissionState.denied:
              case LocationPermissionState.unknown:
                return _LocationPlaceholder(
                  icon: Icons.my_location_outlined,
                  text: 'Allow location to show your position live',
                  action: TextButton(
                    onPressed: () => ref.invalidate(locationPermissionProvider),
                    child: const Text('Allow'),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _MapView extends ConsumerWidget {
  final MapController mapController;
  final bool centeredOnce;
  final VoidCallback onFirstFix;
  const _MapView({required this.mapController, required this.centeredOnce, required this.onFirstFix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(currentPositionStreamProvider);

    return positionAsync.when(
      loading: () => const _LocationPlaceholder(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (_, __) => const _LocationPlaceholder(icon: Icons.location_off_outlined, text: 'Could not get a GPS fix'),
      data: (position) {
        final point = latlng.LatLng(position.latitude, position.longitude);
        if (!centeredOnce) {
          onFirstFix();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mapController.camera.zoom < 15) mapController.move(point, 16);
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.citycalls.vendor',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 46,
                    height: 46,
                    child: const _PulsingDot(),
                  ),
                ]),
              ],
            ),
            // Gradient scrim so the "You are here" chip stays legible over
            // whatever map tile color is underneath it.
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 13, color: AppColors.teal400),
                    SizedBox(width: 5),
                    Text('You are here', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _AccuracyChip(accuracyMeters: position.accuracy),
            ),
          ],
        );
      },
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  final double accuracyMeters;
  const _AccuracyChip({required this.accuracyMeters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
      child: Text('±${accuracyMeters.round()}m', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

// A soft breathing halo behind a solid center dot — the standard "live
// position" marker language from ride-hailing apps, built with a plain
// implicit animation (no extra package needed for something this small).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0, 1),
              child: Container(
                width: 46 * (0.4 + t * 0.6),
                height: 46 * (0.4 + t * 0.6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.info.withValues(alpha: 0.35)),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.info,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocationPlaceholder extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final Widget? child;
  final Widget? action;
  const _LocationPlaceholder({this.icon, this.text, this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate100,
      alignment: Alignment.center,
      child: child ??
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: AppColors.slate400),
              const SizedBox(height: 8),
              Text(text ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500, fontSize: 12.5)),
              if (action != null) action!,
            ],
          ),
    );
  }
}
