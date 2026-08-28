import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Central Google Maps configuration.
///
/// Rendering keys live in the platform manifests (see AndroidManifest.xml,
/// ios/Runner/Info.plist, web/index.html) because the native SDKs read them
/// before Dart starts. The key held here is the *web-service* key used for
/// server-style HTTP calls from Dart — Routes API and Geocoding — which is a
/// different key with different restrictions, and is passed at build time:
///
///   flutter run --dart-define=MAPS_WEB_API_KEY=AIza...
///
/// When it is absent every web-service call is skipped and the caller falls
/// back to straight-line geometry, so the app stays fully usable without it.
class MapConfig {
  const MapConfig._();

  static const String webServiceApiKey =
      String.fromEnvironment('MAPS_WEB_API_KEY');

  /// Whether Routes/Geocoding HTTP calls can be attempted at all.
  static bool get hasWebServiceKey => webServiceApiKey.isNotEmpty;

  /// Tarkwa, Ghana — the platform's operating city. Used as the initial camera
  /// target before the first GPS fix arrives, never as a substitute for one.
  static const LatLng fallbackCenter = LatLng(5.3018, -1.9930);

  static const double cityZoom = 12.0;
  static const double navigationZoom = 16.5;
  static const double trackingZoom = 15.0;

  /// Metres a rider must move before a new GPS fix is emitted. Filters out the
  /// jitter a stationary phone produces, which would otherwise spam the
  /// update_rider_location RPC with no-op writes.
  static const int riderDistanceFilterMeters = 10;

  /// Floor on how often a fix is written back to Supabase. The GPS stream can
  /// fire far faster than this while driving; throttling keeps the write rate
  /// predictable for both the DB and Realtime fan-out.
  static const Duration riderUploadInterval = Duration(seconds: 5);

  /// How far the rider may drift from the last fetched road route before it is
  /// re-requested. Avoids paying for a Routes call on every small deviation.
  static const double routeRefreshThresholdMeters = 120;

  /// Dark-mode map styling. Applied via [GoogleMap.style] so the map does not
  /// glare white inside the app's dark theme.
  static const String darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c33"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9aa7ad"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2c33"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#2c3b42"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7d8b91"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f3d2e"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2b3a41"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a262b"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3a4d55"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0bec5"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2a383f"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e191e"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6771"}]}
]
''';

  /// Light styling is deliberately minimal — Google's default light basemap
  /// already matches the app's light theme. Only POI clutter is trimmed so the
  /// route polyline and stop markers stay the focus.
  static const String lightMapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]
''';

  static String styleFor({required bool isDark}) =>
      isDark ? darkMapStyle : lightMapStyle;

  /// google_maps_flutter has no desktop implementation. Guard map construction
  /// with this so Windows/Linux debug runs show a notice instead of crashing.
  static bool get isMapSupportedPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
