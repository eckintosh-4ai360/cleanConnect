import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Coordinate parsing and geometry helpers shared by every map surface.
class GeoUtils {
  const GeoUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Matches the `"5.603700, -0.187000"` shape that [formatCoordinates] writes
  /// into `profiles.gps_location`, `bins.gps_location` and
  /// `pickup_requests.location`. Tolerates surrounding text such as the
  /// `"(Fallback)"` suffix the register screen appends, and an optional
  /// `lat/lng` label prefix.
  static final RegExp _coordPattern = RegExp(
    r'(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)',
  );

  /// The canonical string form used everywhere coordinates are stored as text.
  static String formatCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// Best-effort extraction of a [LatLng] from a free-text location field.
  ///
  /// Returns null for genuine addresses like `"Home: 123 Green St"` — the
  /// caller then falls back to geocoding or to a coordinate column. Values
  /// outside valid lat/lng ranges are rejected rather than clamped, since an
  /// out-of-range parse means the digits were something else (a phone number,
  /// a price) that happened to fit the pattern.
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

  /// True when the text is coordinates rather than a human-readable address.
  /// Used to decide whether a label is worth showing to the user.
  static bool looksLikeCoordinates(String? raw) => tryParseLatLng(raw) != null;

  /// Great-circle distance in metres (haversine).
  ///
  /// Mirrors Geolocator.distanceBetween, but works on plain [LatLng] values so
  /// it can be used against DB rows and route stops without a device fix.
  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial bearing from [a] to [b] in degrees clockwise from true north.
  /// Used to rotate the rider marker when the GPS fix carries no heading
  /// (common when stationary or on low-end hardware).
  static double bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  /// Camera bounds that contain every supplied point, with a small pad so
  /// markers sitting exactly on the edge are not clipped by the map chrome.
  /// Returns null for an empty list — callers should keep their current camera.
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

  /// "820 m" under a kilometre, "2.4 km" above it.
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// "6 min" / "1 h 12 min". Sub-minute durations round up to 1 so an arriving
  /// rider never reads as "0 min" while still moving.
  static String formatDuration(Duration d) {
    final totalMinutes = math.max(1, (d.inSeconds / 60).ceil());
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }

  /// Straight-line ETA used when the Routes API is unavailable. Assumes a
  /// conservative urban average speed rather than the rider's instantaneous
  /// GPS speed, which swings wildly at traffic lights.
  static Duration estimateDuration(double meters, {double averageKmh = 22}) {
    if (meters <= 0) return Duration.zero;
    final seconds = (meters / (averageKmh * 1000 / 3600)).round();
    return Duration(seconds: seconds);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
