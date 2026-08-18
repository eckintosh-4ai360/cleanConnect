import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';

/// Thin wrapper around [GoogleMap] carrying the app-wide defaults: theme-aware
/// styling, sane gesture/control settings, and a graceful notice on platforms
/// where google_maps_flutter has no implementation (Windows, Linux, macOS).
///
/// Screens still own their markers, polylines and camera logic -- this only
/// removes the boilerplate that was otherwise copy-pasted across four surfaces.
class AppMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final void Function(GoogleMapController controller)? onMapCreated;
  final bool showMyLocationDot;
  final bool showMyLocationButton;
  final bool showCompass;
  final bool showZoomControls;
  final bool liteMode;
  final EdgeInsets padding;
  final void Function(LatLng position)? onTap;
  final MinMaxZoomPreference minMaxZoom;

  const AppMap({
    super.key,
    required this.initialCameraPosition,
    this.markers = const {},
    this.polylines = const {},
    this.circles = const {},
    this.onMapCreated,
    this.showMyLocationDot = false,
    this.showMyLocationButton = false,
    this.showCompass = true,
    this.showZoomControls = false,
    this.liteMode = false,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.minMaxZoom = MinMaxZoomPreference.unbounded,
  });

  @override
  Widget build(BuildContext context) {
    if (!MapConfig.isMapSupportedPlatform) {
      return const _UnsupportedPlatformNotice();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      style: MapConfig.styleFor(isDark: isDark),
      markers: markers,
      polylines: polylines,
      circles: circles,
      onMapCreated: onMapCreated,
      onTap: onTap,
      myLocationEnabled: showMyLocationDot,
      myLocationButtonEnabled: showMyLocationButton,
      compassEnabled: showCompass,
      zoomControlsEnabled: showZoomControls,
      mapToolbarEnabled: false,
      // Tilt and rotate are disabled by default: on a navigation screen the
      // camera is driven programmatically, and a rider accidentally rotating
      // the map mid-drive makes the view hard to recover from.
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      liteModeEnabled: liteMode,
      padding: padding,
      minMaxZoomPreference: minMaxZoom,
    );
  }
}

class _UnsupportedPlatformNotice extends StatelessWidget {
  const _UnsupportedPlatformNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text(
            'Maps are available on Android, iOS and web',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Run the app on a mobile device or in a browser to see live tracking.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

/// Builds and caches the custom [BitmapDescriptor] marker icons.
///
/// google_maps_flutter can only take a bitmap, so each icon is painted once
/// with [Canvas] and reused. Doing this lazily on a background-free path keeps
/// the first map frame from stalling on asset decode.
class MapMarkerIcons {
  MapMarkerIcons._();
  static final MapMarkerIcons instance = MapMarkerIcons._();

  final Map<String, BitmapDescriptor> _cache = {};

  /// A directional chevron used for the moving rider. [colorValue] keeps the
  /// cache key stable across themes.
  Future<BitmapDescriptor> riderMarker({
    required Color color,
    double size = 108,
  }) async {
    return _cached('rider_${color.toARGB32()}_$size', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);

      // Soft halo, mirroring the "live GPS" pulse the old placeholder painted.
      canvas.drawCircle(
        center,
        size / 2,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        center,
        size / 3.2,
        Paint()..color = color.withValues(alpha: 0.30),
      );

      // White disc keeps the arrow readable over dark roads and parkland.
      canvas.drawCircle(center, size / 4.4, Paint()..color = Colors.white);
      canvas.drawCircle(center, size / 5.2, Paint()..color = color);

      // Arrow points up; the marker's rotation property aims it at the heading.
      final arrow = Path()
        ..moveTo(center.dx, center.dy - size / 9)
        ..lineTo(center.dx + size / 13, center.dy + size / 13)
        ..lineTo(center.dx, center.dy + size / 26)
        ..lineTo(center.dx - size / 13, center.dy + size / 13)
        ..close();
      canvas.drawPath(arrow, Paint()..color = Colors.white);

      return _toBitmap(recorder, size, size);
    });
  }

  /// A numbered pin for route stops. [label] is usually the stop order.
  Future<BitmapDescriptor> numberedPin({
    required Color color,
    required String label,
    double size = 96,
  }) async {
    return _cached('pin_${color.toARGB32()}_${label}_$size', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final width = size * 0.78;
      final height = size;
      final headRadius = width / 2;
      final headCenter = Offset(width / 2, headRadius);

      final pin = Path()
        ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
        ..moveTo(width / 2 - headRadius * 0.55, headRadius * 1.35)
        ..lineTo(width / 2, height)
        ..lineTo(width / 2 + headRadius * 0.55, headRadius * 1.35)
        ..close();

      canvas.drawPath(
        pin,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(pin, Paint()..color = color);
      canvas.drawCircle(
        headCenter,
        headRadius * 0.68,
        Paint()..color = Colors.white,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: headRadius * 0.86,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        headCenter - Offset(textPainter.width / 2, textPainter.height / 2),
      );

      return _toBitmap(recorder, width, height);
    });
  }

  /// Destination flag for the customer's doorstep.
  Future<BitmapDescriptor> destinationMarker({
    required Color color,
    double size = 96,
  }) async {
    return _cached('dest_${color.toARGB32()}_$size', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final width = size * 0.78;
      final height = size;
      final headRadius = width / 2;
      final headCenter = Offset(width / 2, headRadius);

      final pin = Path()
        ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
        ..moveTo(width / 2 - headRadius * 0.55, headRadius * 1.35)
        ..lineTo(width / 2, height)
        ..lineTo(width / 2 + headRadius * 0.55, headRadius * 1.35)
        ..close();

      canvas.drawPath(
        pin,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(pin, Paint()..color = color);

      // Simple house glyph -- reads at marker size where an icon font would not.
      final house = Path()
        ..moveTo(headCenter.dx, headCenter.dy - headRadius * 0.46)
        ..lineTo(headCenter.dx + headRadius * 0.48, headCenter.dy)
        ..lineTo(headCenter.dx + headRadius * 0.30, headCenter.dy)
        ..lineTo(headCenter.dx + headRadius * 0.30, headCenter.dy + headRadius * 0.42)
        ..lineTo(headCenter.dx - headRadius * 0.30, headCenter.dy + headRadius * 0.42)
        ..lineTo(headCenter.dx - headRadius * 0.30, headCenter.dy)
        ..lineTo(headCenter.dx - headRadius * 0.48, headCenter.dy)
        ..close();
      canvas.drawPath(house, Paint()..color = Colors.white);

      return _toBitmap(recorder, width, height);
    });
  }

  Future<BitmapDescriptor> _cached(
    String key,
    Future<BitmapDescriptor> Function() build,
  ) async {
    final hit = _cache[key];
    if (hit != null) return hit;
    final built = await build();
    _cache[key] = built;
    return built;
  }

  Future<BitmapDescriptor> _toBitmap(
    ui.PictureRecorder recorder,
    double width,
    double height,
  ) async {
    final image = await recorder.endRecording().toImage(
          width.ceil(),
          height.ceil(),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}

/// Drives smooth marker motion between two GPS fixes.
///
/// Raw fixes arrive every few seconds, so a marker bound directly to them
/// teleports. This interpolates position and heading over [duration], which is
/// what makes tracking read as a vehicle moving rather than a dot jumping.
class MarkerAnimator {
  Timer? _timer;
  LatLng? _current;
  double _currentBearing = 0;

  LatLng? get current => _current;
  double get currentBearing => _currentBearing;

  /// Steps from the current position toward [target], calling [onFrame] about
  /// 30 times a second. Cheaper than a full [AnimationController] and does not
  /// need a TickerProvider, so it can live in a plain state object.
  void animateTo({
    required LatLng target,
    required double targetBearing,
    required void Function(LatLng position, double bearing) onFrame,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    final start = _current;
    final startBearing = _currentBearing;

    if (start == null) {
      _current = target;
      _currentBearing = targetBearing;
      onFrame(target, targetBearing);
      return;
    }

    _timer?.cancel();
    final began = DateTime.now();
    const frame = Duration(milliseconds: 33);

    _timer = Timer.periodic(frame, (timer) {
      final elapsed = DateTime.now().difference(began);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      // Ease-out so the marker decelerates into each fix instead of stopping dead.
      final eased = 1 - math.pow(1 - t, 3).toDouble();

      final lat = start.latitude + (target.latitude - start.latitude) * eased;
      final lng = start.longitude + (target.longitude - start.longitude) * eased;
      final bearing = _lerpBearing(startBearing, targetBearing, eased);

      _current = LatLng(lat, lng);
      _currentBearing = bearing;
      onFrame(_current!, bearing);

      if (t >= 1.0) timer.cancel();
    });
  }

  /// Interpolates the short way around the compass, so 350 deg to 10 deg turns
  /// 20 degrees clockwise rather than spinning 340 the other way.
  double _lerpBearing(double from, double to, double t) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return (from + delta * t) % 360;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _current = null;
    _currentBearing = 0;
  }

  void dispose() {
    _timer?.cancel();
  }
}
