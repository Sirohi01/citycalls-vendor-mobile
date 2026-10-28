import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../providers/location_providers.dart';
import '../theme/app_theme.dart';

// "You are here" map for the Dashboard, plus a full-screen map it opens.
// OpenStreetMap tiles in their original colours (flutter_map — no API key or
// billing), a blue location dot with its GPS-accuracy circle like the phone's
// own maps app, and the attribution OSM's tile policy requires.

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.citycalls.citycalls_vendor';
// OSM's land colour, shown while tiles load so the map never flashes grey.
const _mapBackground = Color(0xFFF2EFE9);
const _dotBlue = Color(0xFF1A73E8);

/// Test-only: replaces the network tile source, since widget tests have no
/// internet (see test/screenshots_test.dart). Always null in the app.
@visibleForTesting
TileProvider? debugMapTileProvider;

class LiveLocationCard extends ConsumerWidget {
  const LiveLocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(locationPermissionProvider);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: _PermissionGate(
          permission: permission,
          builder: (position) => _CardMap(position: position),
        ),
      ),
    );
  }
}

// Shows the map once location is allowed and a fix exists; otherwise a
// placeholder with the right action (allow / turn on / open settings).
class _PermissionGate extends ConsumerWidget {
  final AsyncValue<LocationPermissionState> permission;
  final Widget Function(Position position) builder;
  const _PermissionGate({required this.permission, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return permission.when(
      loading: () => const _MapPlaceholder(loading: true),
      error: (_, __) => const _MapPlaceholder(
        icon: Icons.location_off_rounded,
        title: 'Location unavailable',
        message: 'We could not read your location on this phone.',
      ),
      data: (state) {
        switch (state) {
          case LocationPermissionState.granted:
            return ref.watch(currentPositionStreamProvider).when(
                  loading: () => const _MapPlaceholder(loading: true),
                  error: (_, __) => const _MapPlaceholder(
                    icon: Icons.gps_off_rounded,
                    title: 'Waiting for GPS',
                    message: 'Move to an open area to get a location fix.',
                  ),
                  data: builder,
                );
          case LocationPermissionState.serviceDisabled:
            return _MapPlaceholder(
              icon: Icons.location_disabled_rounded,
              title: 'Location is off',
              message: 'Turn on GPS so customers can see you arriving.',
              actionLabel: 'Turn on location',
              onAction: () async {
                await Geolocator.openLocationSettings();
                ref.invalidate(locationPermissionProvider);
              },
            );
          case LocationPermissionState.deniedForever:
            return _MapPlaceholder(
              icon: Icons.location_off_rounded,
              title: 'Location permission blocked',
              message: 'Allow location for CityCalls Field in settings.',
              actionLabel: 'Open settings',
              onAction: () async {
                await Geolocator.openAppSettings();
                ref.invalidate(locationPermissionProvider);
              },
            );
          case LocationPermissionState.denied:
          case LocationPermissionState.unknown:
            return _MapPlaceholder(
              icon: Icons.my_location_rounded,
              title: 'Show your live location',
              message: 'Customers see you on the map while you are on the way.',
              actionLabel: 'Allow location',
              onAction: () => ref.invalidate(locationPermissionProvider),
            );
        }
      },
    );
  }
}

/// The map itself: OSM tiles, accuracy circle and the location dot.
class _MapCore extends StatelessWidget {
  final Position position;
  final MapController controller;
  final bool interactive;
  final double initialZoom;
  final void Function(MapCamera camera, bool hasGesture)? onMoved;
  const _MapCore({
    required this.position,
    required this.controller,
    required this.interactive,
    this.initialZoom = 16,
    this.onMoved,
  });

  @override
  Widget build(BuildContext context) {
    final point = latlng.LatLng(position.latitude, position.longitude);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: point,
        initialZoom: initialZoom,
        minZoom: 4,
        maxZoom: 19,
        backgroundColor: _mapBackground,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onPositionChanged: onMoved == null
            ? null
            : (camera, hasGesture) => onMoved!(camera, hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: _userAgent,
          maxNativeZoom: 19,
          tileProvider: debugMapTileProvider,
        ),
        CircleLayer(circles: [
          CircleMarker(
            point: point,
            radius: math.max(position.accuracy, 8),
            useRadiusInMeter: true,
            color: _dotBlue.withValues(alpha: 0.12),
            borderColor: _dotBlue.withValues(alpha: 0.35),
            borderStrokeWidth: 1,
          ),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: point,
            width: 64,
            height: 64,
            child: const _LocationDot(),
          ),
        ]),
      ],
    );
  }
}

class _CardMap extends StatefulWidget {
  final Position position;
  const _CardMap({required this.position});

  @override
  State<_CardMap> createState() => _CardMapState();
}

class _CardMapState extends State<_CardMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(covariant _CardMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preview always follows the technician.
    final p = widget.position;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _controller.move(latlng.LatLng(p.latitude, p.longitude),
            _controller.camera.zoom);
      } catch (_) {}
    });
  }

  void _openFullMap() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FullMapScreen()));

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // A preview inside a scrolling page: panning it would fight the
        // page scroll, so it's still and a tap opens the full map.
        _MapCore(
            position: widget.position,
            controller: _controller,
            interactive: false),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: _openFullMap),
          ),
        ),
        const Positioned(left: 12, top: 12, child: _LiveChip()),
        Positioned(
          right: 12,
          top: 12,
          child: _MapButton(
            icon: Icons.open_in_full_rounded,
            tooltip: 'Open full map',
            onTap: _openFullMap,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _InfoStrip(
            position: widget.position,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Open map',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _dotBlue)),
                Icon(Icons.chevron_right_rounded, size: 18, color: _dotBlue),
              ],
            ),
            onTap: _openFullMap,
          ),
        ),
        const Positioned(right: 14, bottom: 80, child: _Attribution()),
      ],
    );
  }
}

/// Full-screen live map: pan and zoom freely, zoom buttons, and a "my
/// location" button that re-centres and keeps following the technician.
class FullMapScreen extends ConsumerStatefulWidget {
  const FullMapScreen({super.key});

  @override
  ConsumerState<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends ConsumerState<FullMapScreen> {
  final _controller = MapController();
  bool _following = true;

  void _zoom(double delta) {
    try {
      final cam = _controller.camera;
      _controller.move(cam.center, (cam.zoom + delta).clamp(4, 19));
    } catch (_) {}
  }

  void _recenter(Position p) {
    setState(() => _following = true);
    try {
      _controller.move(latlng.LatLng(p.latitude, p.longitude),
          math.max(_controller.camera.zoom, 16));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(locationPermissionProvider);

    ref.listen(currentPositionStreamProvider, (_, next) {
      final p = next.valueOrNull;
      if (p == null || !_following) return;
      try {
        _controller.move(
            latlng.LatLng(p.latitude, p.longitude), _controller.camera.zoom);
      } catch (_) {}
    });

    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _mapBackground,
        body: _PermissionGate(
          permission: permission,
          builder: (position) => Stack(
            fit: StackFit.expand,
            children: [
              _MapCore(
                position: position,
                controller: _controller,
                interactive: true,
                initialZoom: 17,
                onMoved: (_, hasGesture) {
                  if (hasGesture && _following) {
                    setState(() => _following = false);
                  }
                },
              ),
              Positioned(
                left: 12,
                top: top + 10,
                child: _MapButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                left: 64,
                right: 64,
                top: top + 14,
                child: const Center(child: _LiveChip()),
              ),
              Positioned(
                right: 12,
                bottom: bottom + 150,
                child: Column(
                  children: [
                    _ZoomControl(
                        onZoomIn: () => _zoom(1), onZoomOut: () => _zoom(-1)),
                    const SizedBox(height: 12),
                    _MapButton(
                      icon: _following
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      tooltip: 'My location',
                      color: _following ? _dotBlue : AppColors.ink,
                      size: 48,
                      onTap: () => _recenter(position),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                bottom: bottom + 130,
                child: const _Attribution(),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: bottom + 14,
                child: _InfoStrip(position: position, detailed: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkDot(),
          SizedBox(width: 7),
          Text('LIVE',
              style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
          SizedBox(width: 6),
          Text('Your location',
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final double size;
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.ink,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.48, color: color),
          ),
        ),
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _ZoomControl({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Tooltip(
            message: tip,
            child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, size: 24, color: AppColors.ink)),
          ),
        );
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          button(Icons.add_rounded, 'Zoom in', onZoomIn),
          Container(width: 30, height: 1, color: AppColors.line),
          button(Icons.remove_rounded, 'Zoom out', onZoomOut),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('© OpenStreetMap contributors',
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.slate600)),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final Position position;
  final bool detailed;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _InfoStrip(
      {required this.position,
      this.detailed = false,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final accuracy = position.accuracy.round();
    final strong = accuracy <= 30;
    final accuracyChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (strong ? AppColors.green : AppColors.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('±$accuracy m',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: strong ? AppColors.greenDark : AppColors.gold400)),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, detailed ? 14 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _dotBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.near_me_rounded,
                        size: 19, color: _dotBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("You're here",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        Text(
                            detailed
                                ? 'GPS accuracy ±$accuracy m'
                                : 'Shared with customers while you travel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted)),
                      ],
                    ),
                  ),
                  trailing ?? accuracyChip,
                ],
              ),
              if (detailed) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.page,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop_outlined,
                          size: 17, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700),
                        ),
                      ),
                      const Text('Live while on duty',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// The phone-maps style location dot: white-ringed blue dot with a soft
// pulsing halo.
class _LocationDot extends StatefulWidget {
  const _LocationDot();

  @override
  State<_LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<_LocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
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
            Container(
              width: 64 * (0.35 + t * 0.65),
              height: 64 * (0.35 + t * 0.65),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotBlue.withValues(alpha: 0.30 * (1 - t)),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotBlue,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: AppColors.green, shape: BoxShape.circle),
      ),
    );
  }
}

// Shown instead of the map when there's no position to show: a drawn
// street-grid backdrop with a centred message and action, so the card keeps
// its shape and still reads as a map.
class _MapPlaceholder extends StatelessWidget {
  final bool loading;
  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _MapPlaceholder({
    this.loading = false,
    this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _StreetGridPainter()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
        Center(
          child: loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _dotBlue,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(_dotBlue),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(title ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text(message ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.muted)),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: _dotBlue,
                            minimumSize: const Size(160, 42),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _StreetGridPainter extends CustomPainter {
  const _StreetGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _mapBackground);
    final block = Paint()..color = const Color(0xFFE8E4DC);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final major = Paint()
      ..color = const Color(0xFFFCD68A)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final minor = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final r = Rect.fromLTWH(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height,
          40 + rnd.nextDouble() * 70,
          26 + rnd.nextDouble() * 40);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), block);
    }
    for (double x = 30; x < size.width; x += 70) {
      canvas.drawLine(Offset(x, 0), Offset(x - 30, size.height), minor);
    }
    for (double y = 24; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), minor);
    }
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.42, size.height), road);
    canvas.drawLine(Offset(0, size.height * 0.62),
        Offset(size.width, size.height * 0.38), major);
    final park = Paint()..color = const Color(0xFFC8E6C0);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.78), 34, park);
    final water = Paint()..color = const Color(0xFFAAD3DF);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.15), 28, water);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
