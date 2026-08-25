import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map geometry and coordinate parsing helpers
class GeoUtils {
  const GeoUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  // Regex to match "lat, lng" string pairs
  static final RegExp _coordPattern = RegExp(
    r'(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)',
  );

  // Formats lat/lng into canonical string
  static String formatCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  // Parses coordinates from a string; returns null if invalid or an address
  static LatLng? tryParseLatLng(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = _coordPattern.firstMatch(raw);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;

    return LatLng(lat, lng);
  }

  // True if string matches coordinate format
  static bool looksLikeCoordinates(String? raw) => tryParseLatLng(raw) != null;

  // Great-circle haversine distance in meters
  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
  }

  // Bearing in degrees from point A to B
  static double bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  // Computes map viewport bounds for a set of points
  static LatLngBounds? boundsFor(Iterable<LatLng> points, {double padDegrees = 0.004}) {
    final list = points.toList();
    if (list.isEmpty) return null;

    var minLat = list.first.latitude, maxLat = list.first.latitude;
    var minLng = list.first.longitude, maxLng = list.first.longitude;
    for (final p in list) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(
        math.max(-90.0, minLat - padDegrees),
        math.max(-180.0, minLng - padDegrees),
      ),
      northeast: LatLng(
        math.min(90.0, maxLat + padDegrees),
        math.min(180.0, maxLng + padDegrees),
      ),
    );
  }

  // Formats meters to readable distance (e.g. "820 m" or "2.4 km")
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Formats duration into "X min" or "X h Y min"
  static String formatDuration(Duration d) {
    final totalMinutes = math.max(1, (d.inSeconds / 60).ceil());
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }

  // Straight-line fallback ETA calculation
  static Duration estimateDuration(double meters, {double averageKmh = 22}) {
    if (meters <= 0) return Duration.zero;
    final seconds = (meters / (averageKmh * 1000 / 3600)).round();
    return Duration(seconds: seconds);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
