import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';
import '../utils/geo_utils.dart';

/// A drivable route between two points, plus the turn-by-turn text for the
/// current leg. [isFallback] tells the UI whether this came off the Routes API
/// or is the straight-line approximation, so it can label the ETA honestly
/// instead of presenting a guess as a traffic-aware estimate.
class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final Duration duration;
  final List<RouteStep> steps;
  final bool isFallback;

  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.duration,
    required this.steps,
    required this.isFallback,
  });

  String get distanceLabel => GeoUtils.formatDistance(distanceMeters);
  String get durationLabel => GeoUtils.formatDuration(duration);

  RouteStep? get nextStep => steps.isEmpty ? null : steps.first;
}

/// One manoeuvre from the Routes API, e.g. "Turn right onto Ring Road East".
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final String maneuver;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.maneuver,
  });

  String get distanceLabel => GeoUtils.formatDistance(distanceMeters);
}

/// Google Routes API client with a straight-line fallback.
///
/// Every method degrades instead of throwing: with no API key, no network, or
/// a quota error, the caller still gets a usable [RouteResult] built from
/// haversine geometry. That keeps navigation working offline and keeps the
/// screens honest -- `isFallback` surfaces which one they got.
class DirectionsService {
  DirectionsService._();
  static final DirectionsService instance = DirectionsService._();

  static const String _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String _geocodeEndpoint =
      'https://maps.googleapis.com/maps/api/geocode/json';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Cache keyed by rounded origin/destination. A rider's GPS jitters every few
  /// seconds; without this the same route would be re-billed continuously while
  /// they sit at a junction.
  final Map<String, RouteResult> _routeCache = {};

  /// Road-following route from [origin] to [destination].
  ///
  /// [travelMode] accepts the Routes API values -- 'DRIVE' for vans,
  /// 'TWO_WHEELER' for motorbikes, which routes through bike-legal roads and
  /// gives a realistic ETA for Accra traffic.
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'DRIVE',
    bool includeSteps = true,
  }) async {
    if (!MapConfig.hasWebServiceKey) {
      return _straightLine(origin, destination);
    }

    final cacheKey = _cacheKey(origin, destination, travelMode);
    final cached = _routeCache[cacheKey];
    if (cached != null) return cached;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _routesEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': MapConfig.webServiceApiKey,
            // The Routes API bills by the fields requested, so ask only for
            // what the navigation UI actually renders.
            'X-Goog-FieldMask': includeSteps
                ? 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,'
                    'routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters'
                : 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
          },
        ),
        data: {
          'origin': _waypoint(origin),
          'destination': _waypoint(destination),
          'travelMode': travelMode,
          // TRAFFIC_AWARE is the cheaper of the two traffic models and is
          // accurate enough for a pickup ETA; TRAFFIC_AWARE_OPTIMAL costs more
          // and is aimed at long-haul routing.
          if (travelMode == 'DRIVE') 'routingPreference': 'TRAFFIC_AWARE',
          'polylineQuality': 'HIGH_QUALITY',
          'languageCode': 'en-GB',
          'units': 'METRIC',
        },
      );

      final result = _parseRoute(response.data);
      if (result != null) {
        _routeCache[cacheKey] = result;
        return result;
      }
      debugPrint('DirectionsService: Routes API returned no usable route.');
    } on DioException catch (e) {
      // 403 = key not enabled for Routes API, 429 = quota exhausted. Both are
      // configuration problems the developer needs to see in the log, not
      // user-facing errors -- the fallback below keeps the screen working.
      debugPrint(
        'DirectionsService: Routes API ${e.response?.statusCode} - '
        '${e.response?.data ?? e.message}',
      );
    } catch (e) {
      debugPrint('DirectionsService: unexpected routing failure - $e');
    }

    return _straightLine(origin, destination);
  }

  /// Resolves a human-readable address to coordinates.
  ///
  /// Only used for legacy pickup rows whose `location` column holds an address
  /// rather than coordinates; new requests store lat/lng directly, so this
  /// should be a rare call. Returns null when it cannot resolve, letting the
  /// caller fall back to the customer's registered bin location.
  Future<LatLng?> geocodeAddress(String address, {String region = 'gh'}) async {
    if (!MapConfig.hasWebServiceKey || address.trim().isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _geocodeEndpoint,
        queryParameters: {
          'address': address,
          'region': region,
          'key': MapConfig.webServiceApiKey,
        },
      );

      final data = response.data;
      if (data == null || data['status'] != 'OK') {
        debugPrint('DirectionsService: geocode "$address" -> ${data?['status']}');
        return null;
      }

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final geometry =
          (results.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      if (loc == null) return null;

      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      return LatLng(lat, lng);
    } catch (e) {
      debugPrint('DirectionsService: geocode failed - $e');
      return null;
    }
  }

  /// Resolves coordinates to a human-readable address, for labelling a pin the
  /// customer just dropped on the map. Returns null (never throws) when the
  /// key is absent or the point has no known address -- callers fall back to
  /// showing the raw coordinates.
  Future<String?> reverseGeocode(LatLng point) async {
    if (!MapConfig.hasWebServiceKey) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _geocodeEndpoint,
        queryParameters: {
          'latlng': '${point.latitude},${point.longitude}',
          'key': MapConfig.webServiceApiKey,
        },
      );

      final data = response.data;
      if (data == null || data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      return (results.first as Map<String, dynamic>)['formatted_address']
          as String?;
    } catch (e) {
      debugPrint('DirectionsService: reverse geocode failed - $e');
      return null;
    }
  }

  void clearCache() => _routeCache.clear();

  // -- Internals ------------------------------------------------------------

  Map<String, dynamic> _waypoint(LatLng p) => {
        'location': {
          'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
        },
      };

  /// Rounded to ~11 m so tiny GPS drift maps onto the same cache entry.
  String _cacheKey(LatLng a, LatLng b, String mode) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
      '|${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}|$mode';

  RouteResult? _parseRoute(Map<String, dynamic>? data) {
    final routes = data?['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final polylineNode = route['polyline'] as Map<String, dynamic>?;
    final encoded = polylineNode?['encodedPolyline'] as String?;
    if (encoded == null) return null;

    final steps = <RouteStep>[];
    final legs = route['legs'] as List<dynamic>?;
    if (legs != null) {
      for (final leg in legs.cast<Map<String, dynamic>>()) {
        final legSteps = leg['steps'] as List<dynamic>? ?? const [];
        for (final step in legSteps.cast<Map<String, dynamic>>()) {
          final nav = step['navigationInstruction'] as Map<String, dynamic>?;
          final instruction = nav?['instructions'] as String?;
          if (instruction == null || instruction.isEmpty) continue;
          steps.add(
            RouteStep(
              instruction: instruction,
              distanceMeters: (step['distanceMeters'] as num?)?.toDouble() ?? 0,
              maneuver: nav?['maneuver'] as String? ?? '',
            ),
          );
        }
      }
    }

    return RouteResult(
      polyline: decodePolyline(encoded),
      distanceMeters: (route['distanceMeters'] as num?)?.toDouble() ?? 0,
      duration: _parseDuration(route['duration'] as String?),
      steps: steps,
      isFallback: false,
    );
  }

  /// Routes API returns protobuf durations as `"832s"`.
  Duration _parseDuration(String? raw) {
    if (raw == null) return Duration.zero;
    final seconds = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    return Duration(seconds: seconds ?? 0);
  }

  RouteResult _straightLine(LatLng origin, LatLng destination) {
    final meters = GeoUtils.distanceMeters(origin, destination);
    return RouteResult(
      polyline: [origin, destination],
      distanceMeters: meters,
      duration: GeoUtils.estimateDuration(meters),
      steps: const [],
      isFallback: true,
    );
  }

  /// Google's encoded polyline algorithm, format 1.
  ///
  /// Implemented here rather than pulled in as a dependency -- it is ~30 lines
  /// and the published packages wrap the legacy Directions API we are not using.
  @visibleForTesting
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      final latResult = _decodeValue(encoded, index);
      lat += latResult.value;
      index = latResult.nextIndex;

      if (index >= encoded.length) break;

      final lngResult = _decodeValue(encoded, index);
      lng += lngResult.value;
      index = lngResult.nextIndex;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Reads one zig-zag-encoded varint starting at [start].
  static _VarintRead _decodeValue(String encoded, int start) {
    var index = start;
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);

    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _VarintRead(value, index);
  }
}

class _VarintRead {
  final int value;
  final int nextIndex;
  const _VarintRead(this.value, this.nextIndex);
}
