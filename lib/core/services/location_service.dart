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
    if (permission == LocationPermission.denied) {
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

  // Get single GPS fix, with fallback to last known position
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (await ensurePermission() != LocationAccess.granted) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      );
    } catch (e) {
      debugPrint('LocationService.currentPosition failed: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // Live GPS position stream (uses foreground service during active jobs)
  Stream<Position> positionStream({
    bool forJob = false,
    int distanceFilterMeters = MapConfig.riderDistanceFilterMeters,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: _settingsFor(
        forJob: forJob,
        distanceFilterMeters: distanceFilterMeters,
      ),
    );
  }

  LocationSettings _settingsFor({
    required bool forJob,
    required int distanceFilterMeters,
  }) {
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
        foregroundNotificationConfig: forJob
            ? const ForegroundNotificationConfig(
                notificationTitle: 'CleanConnect — on an active pickup',
                notificationText:
                    'Sharing your location with dispatch and the customer.',
                notificationChannelName: 'Live pickup tracking',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: forJob,
        showBackgroundLocationIndicator: forJob,
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
