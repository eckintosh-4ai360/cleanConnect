import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';

/// Permission status for location access
enum LocationAccess {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Why the GPS stream has to keep running with the app in the background.
enum BackgroundTracking {
  /// Foreground only.
  none,

  /// The rider is on an active pickup.
  job,

  /// The rider holds a company bike, which is tracked even while off duty.
  bike,
}

/// Geolocator wrapper managing permissions and rider tracking streams
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Requests foreground location permission
  Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  /// Get single GPS fix, with a 4-tier resilient fallback:
  /// 1. Platform-optimized High Accuracy fix (18s timeout)
  /// 2. Medium Accuracy fix (Wi-Fi / Cell tower triangulation, 8s timeout - works reliably indoors)
  /// 3. Native Android LocationManager fix (bypasses Google Play Services, 8s timeout)
  /// 4. Last known cached position from OS
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 18),
  }) async {
    if (await ensurePermission() != LocationAccess.granted) return null;

    // 1. Primary attempt: Platform-specific settings for the requested accuracy
    try {
      final LocationSettings primarySettings;
      if (kIsWeb) {
        primarySettings = LocationSettings(accuracy: accuracy, timeLimit: timeout);
      } else if (Platform.isAndroid) {
        primarySettings = AndroidSettings(
          accuracy: accuracy,
          timeLimit: timeout,
          forceLocationManager: false,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        primarySettings = AppleSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        );
      } else {
        primarySettings = LocationSettings(accuracy: accuracy, timeLimit: timeout);
      }

      return await Geolocator.getCurrentPosition(locationSettings: primarySettings);
    } catch (e) {
      debugPrint('LocationService.currentPosition primary failed ($accuracy): $e');
    }

    // 2. Fallback attempt 1: Medium accuracy (Wi-Fi / Cell tower triangulation)
    // Resolves in ~1s indoors where GPS satellite signals are blocked or weak.
    if (accuracy == LocationAccuracy.high ||
        accuracy == LocationAccuracy.best ||
        accuracy == LocationAccuracy.bestForNavigation) {
      try {
        final LocationSettings mediumSettings;
        if (kIsWeb) {
          mediumSettings = const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          );
        } else if (Platform.isAndroid) {
          mediumSettings = AndroidSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
            forceLocationManager: false,
          );
        } else {
          mediumSettings = const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          );
        }
        return await Geolocator.getCurrentPosition(locationSettings: mediumSettings);
      } catch (e) {
        debugPrint('LocationService.currentPosition fallback medium failed: $e');
      }
    }

    // 3. Fallback attempt 2 (Android only): Native LocationManager
    // In case Google Play Services FusedLocationProvider is unavailable or stalled.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final lmSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
          forceLocationManager: true,
        );
        return await Geolocator.getCurrentPosition(locationSettings: lmSettings);
      } catch (e) {
        debugPrint('LocationService.currentPosition forceLocationManager failed: $e');
      }
    }

    // 4. Fallback attempt 3: Last known cached position
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint('LocationService.currentPosition using lastKnownPosition');
        return lastKnown;
      }
    } catch (e) {
      debugPrint('LocationService.currentPosition getLastKnownPosition failed: $e');
    }

    return null;
  }

  // Live GPS position stream. Anything but [BackgroundTracking.none] runs as a
  // foreground service (Android) / background location session (iOS), so it
  // survives the phone being locked or the rider switching apps.
  Stream<Position> positionStream({
    BackgroundTracking background = BackgroundTracking.none,
    String? bikeLabel,
    int distanceFilterMeters = MapConfig.riderDistanceFilterMeters,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: _settingsFor(
        background: background,
        bikeLabel: bikeLabel,
        distanceFilterMeters: distanceFilterMeters,
      ),
    );
  }

  LocationSettings _settingsFor({
    required BackgroundTracking background,
    required String? bikeLabel,
    required int distanceFilterMeters,
  }) {
    final inBackground = background != BackgroundTracking.none;

    if (kIsWeb) {
      return LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      );
    }

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        intervalDuration: const Duration(seconds: 5),
        forceLocationManager: false,
        foregroundNotificationConfig: switch (background) {
          BackgroundTracking.none => null,
          BackgroundTracking.job => const ForegroundNotificationConfig(
              notificationTitle: 'CleanConnect — on an active pickup',
              notificationText:
                  'Sharing your location with dispatch and the customer.',
              notificationChannelName: 'Live pickup tracking',
              enableWakeLock: true,
              setOngoing: true,
            ),
          // Riders are told, every time, that a company bike is being tracked.
          BackgroundTracking.bike => ForegroundNotificationConfig(
              notificationTitle: 'CleanConnect — company bike tracking',
              notificationText:
                  'Your location is shared with dispatch while ${bikeLabel ?? 'a company bike'} is assigned to you.',
              notificationChannelName: 'Company bike tracking',
              enableWakeLock: true,
              setOngoing: true,
            ),
        },
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: inBackground,
        showBackgroundLocationIndicator: inBackground,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LatLng toLatLng(Position p) => LatLng(p.latitude, p.longitude);
}
