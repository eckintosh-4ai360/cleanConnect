import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/geo_utils.dart';
import 'rider_providers.dart';

part 'rider_tracking_provider.g.dart';

/// Live tracking state of the rider's device and broadcast status
@immutable
class RiderTrackingState {
  final Position? position;
  final LocationAccess? access;
  final bool isBroadcasting;
  final String? jobId;
  final String? uploadError;
  final DateTime? lastUploadAt;

  const RiderTrackingState({
    this.position,
    this.access,
    this.isBroadcasting = false,
    this.jobId,
    this.uploadError,
    this.lastUploadAt,
  });

  bool get hasFix => position != null;

  LatLng? get latLng =>
      position == null ? null : LatLng(position!.latitude, position!.longitude);

  // Heading in degrees (null if stationary or unavailable)
  double? get heading {
    final h = position?.heading;
    if (h == null || h < 0) return null;
    return h;
  }

  // Speed in km/h
  double get speedKmh {
    final s = position?.speed ?? 0;
    return s <= 0 ? 0 : s * 3.6;
  }

  bool get isPermissionBlocked =>
      access == LocationAccess.denied ||
      access == LocationAccess.deniedForever ||
      access == LocationAccess.serviceDisabled;

  RiderTrackingState copyWith({
    Position? position,
    LocationAccess? access,
    bool? isBroadcasting,
    String? jobId,
    String? uploadError,
    DateTime? lastUploadAt,
    bool clearJobId = false,
    bool clearUploadError = false,
  }) {
    return RiderTrackingState(
      position: position ?? this.position,
      access: access ?? this.access,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      jobId: clearJobId ? null : (jobId ?? this.jobId),
      uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
      lastUploadAt: lastUploadAt ?? this.lastUploadAt,
    );
  }
}

/// Streams rider GPS updates and broadcasts location to Supabase
@Riverpod(keepAlive: true)
class RiderTracking extends _$RiderTracking {
  StreamSubscription<Position>? _subscription;
  Timer? _uploadThrottle;
  Position? _pendingUpload;
  DateTime? _lastUploadAt;

  @override
  RiderTrackingState build() {
    ref.onDispose(_teardown);
    return const RiderTrackingState();
  }

  // Starts continuous GPS tracking (with optional foreground service for active job)
  Future<void> start({String? jobId}) async {
    if (state.isBroadcasting && state.jobId == jobId) return;

    final needsForegroundService = jobId != null;
    final hadForegroundService = state.jobId != null;

    if (_subscription != null &&
        state.isBroadcasting &&
        needsForegroundService == hadForegroundService) {
      state = state.copyWith(jobId: jobId, clearJobId: jobId == null);
      return;
    }

    final access = await LocationService.instance.ensurePermission();
    state = state.copyWith(access: access);
    if (access != LocationAccess.granted) {
      state = state.copyWith(isBroadcasting: false);
      return;
    }

    // Seed initial position fix
    final initial = await LocationService.instance.currentPosition();
    if (initial != null) {
      state = state.copyWith(position: initial);
      _queueUpload(initial);
    }

    await _subscription?.cancel();
    _subscription = LocationService.instance
        .positionStream(forJob: jobId != null)
        .listen(
          _onPosition,
          onError: (Object e) {
            debugPrint('RiderTracking: position stream error - $e');
            state = state.copyWith(uploadError: 'GPS signal lost');
          },
          cancelOnError: false,
        );

    state = state.copyWith(
      isBroadcasting: true,
      jobId: jobId,
      clearJobId: jobId == null,
      clearUploadError: true,
    );
  }

  // Stops GPS stream and background service
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _uploadThrottle?.cancel();
    _uploadThrottle = null;
    _pendingUpload = null;
    state = state.copyWith(isBroadcasting: false, clearJobId: true);
  }

  // Re-evaluates location permission
  Future<LocationAccess> retryPermission() async {
    final access = await LocationService.instance.ensurePermission();
    state = state.copyWith(access: access);
    if (access == LocationAccess.granted && !state.isBroadcasting) {
      await start(jobId: state.jobId);
    }
    return access;
  }

  void _onPosition(Position position) {
    state = state.copyWith(position: position);
    _queueUpload(position);
  }

  // Throttles database location writes
  void _queueUpload(Position position) {
    _pendingUpload = position;

    final since = _lastUploadAt == null
        ? null
        : DateTime.now().difference(_lastUploadAt!);
    if (since == null || since >= MapConfig.riderUploadInterval) {
      _flushUpload();
      return;
    }

    _uploadThrottle ??= Timer(
      MapConfig.riderUploadInterval - since,
      _flushUpload,
    );
  }

  Future<void> _flushUpload() async {
    _uploadThrottle?.cancel();
    _uploadThrottle = null;

    final position = _pendingUpload;
    if (position == null) return;
    _pendingUpload = null;
    _lastUploadAt = DateTime.now();

    try {
      await ref.read(riderProfileProvider.notifier).updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading >= 0 ? position.heading : null,
            speed: position.speed > 0 ? position.speed * 3.6 : 0,
            currentJobId: state.jobId,
          );
      if (state.uploadError != null) {
        state = state.copyWith(
          clearUploadError: true,
          lastUploadAt: _lastUploadAt,
        );
      } else {
        state = state.copyWith(lastUploadAt: _lastUploadAt);
      }
    } catch (e) {
      debugPrint('RiderTracking: location upload failed - $e');
      state = state.copyWith(uploadError: 'Not syncing with dispatch');
    }
  }

  void _teardown() {
    _subscription?.cancel();
    _uploadThrottle?.cancel();
  }
}

// Calculates distance in meters from current rider position to target
double? riderDistanceTo(RiderTrackingState state, LatLng? target) {
  final from = state.latLng;
  if (from == null || target == null) return null;
  return GeoUtils.distanceMeters(from, target);
}
