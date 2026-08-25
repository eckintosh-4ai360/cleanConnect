import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/map_config.dart';

/// Reusable GoogleMap wrapper with default themes and platform fallbacks
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

/// Custom map marker icon builder and cache
class MapMarkerIcons {
  MapMarkerIcons._();
  static final MapMarkerIcons instance = MapMarkerIcons._();

  final Map<String, BitmapDescriptor> _cache = {};

  // Directional rider chevron marker
  Future<BitmapDescriptor> riderMarker({
    required Color color,
    double size = 108,
  }) async {
    return _cached('rider_${color.toARGB32()}_$size', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);

      // Outer halo
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

      // Disc and inner color
      canvas.drawCircle(center, size / 4.4, Paint()..color = Colors.white);
      canvas.drawCircle(center, size / 5.2, Paint()..color = color);

      // Chevron arrow
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

  // Numbered pin marker for route stops
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

  // Destination house pin marker
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

      // House icon glyph
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

/// Smoothly animates marker position and bearing between GPS updates
class MarkerAnimator {
  Timer? _timer;
  LatLng? _current;
  double _currentBearing = 0;

  LatLng? get current => _current;
  double get currentBearing => _currentBearing;

  // Interpolates marker position and heading at ~30 fps
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

  // Angular interpolation taking the shortest arc
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
