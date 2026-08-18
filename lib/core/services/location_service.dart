import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/map_config.dart';

/// Outcome of asking the OS for location access, so callers can render a
/// specific message instead of a generic failure.
enum LocationAccess {
  granted,

  /// Refused this time; asking again is allowed.
  denied,

  /// Refused permanently — only Settings can undo it, so the UI must offer
  /// [openAppSettings] rather than re-prompting.
  deniedForever,

  /// Permission is fine but the device's location toggle is off.
  serviceDisabled,
}

/// Thin wrapper over geolocator that centralises permission flow and the
/// platform-specific settings needed for continuous rider tracking.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Requests foreground location, reporting exactly why it failed.
  ///
  /// The service check runs first: on a device with location switched off,
  /// the permission dialog can be accepted and every subsequent fix still
  /// times out, which reads to the user as the app being broken.
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

  /// One-shot fix. Returns null rather than throwing so callers can degrade to
  /// a last-known position or the city fallback without a try/catch each time.
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
      // A cached fix beats no map at all while the GPS chip is still warming up.
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Continuous position stream.
  ///
  /// With [forJob] true the Android stream is promoted to a foreground service
  /// with a persistent notification, so tracking survives the rider locking
  /// their screen or switching to the Google Maps app mid-delivery. Android 14
  /// kills a background location stream within minutes otherwise, which is what
  /// makes an active pickup silently stop updating for dispatch.
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
        // Upper bound on silence from the OS. Without it a stationary rider
        // produces no events at all and the UI cannot distinguish "parked"
        // from "GPS died".
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
        // Both are required for iOS to keep delivering fixes with the app
        // backgrounded; pauseAutomatically would otherwise stop the stream
        // when iOS decides the rider has stopped moving.
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

  /// Deep-links to the OS app settings page — the only recovery path after
  /// [LocationAccess.deniedForever].
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the system location toggle for [LocationAccess.serviceDisabled].
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LatLng toLatLng(Position p) => LatLng(p.latitude, p.longitude);
}
