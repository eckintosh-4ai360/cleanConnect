import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/rider_entities.dart';
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

  /// The company bike being tracked, if one is assigned to this rider.
  final AssignedBikeEntity? bike;

  const RiderTrackingState({
    this.position,
    this.access,
    this.isBroadcasting = false,
    this.jobId,
    this.uploadError,
    this.lastUploadAt,
    this.bike,
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
    AssignedBikeEntity? bike,
    bool clearJobId = false,
    bool clearUploadError = false,
    bool clearBike = false,
  }) {
    return RiderTrackingState(
      position: position ?? this.position,
      access: access ?? this.access,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      jobId: clearJobId ? null : (jobId ?? this.jobId),
      uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
      lastUploadAt: lastUploadAt ?? this.lastUploadAt,
      bike: clearBike ? null : (bike ?? this.bike),
    );
  }
}

/// Streams rider GPS updates and broadcasts location to Supabase
@Riverpod(keepAlive: true)
class RiderTracking extends _$RiderTracking {
  /// While a bike is assigned, a fix is re-sent at least this often even when
  /// the rider is parked, so a gap in the admin's trail means the phone really
  /// went silent rather than the bike standing still. The server keeps one
  /// point per two minutes when nothing moves.
  static const Duration _bikeHeartbeat = Duration(minutes: 2);

  StreamSubscription<Position>? _subscription;
  Timer? _uploadThrottle;
  Timer? _heartbeat;
  Position? _pendingUpload;
  DateTime? _lastUploadAt;
  BackgroundTracking _streamMode = BackgroundTracking.none;

  @override
  RiderTrackingState build() {
    ref.onDispose(_teardown);
    return const RiderTrackingState();
  }

  BackgroundTracking _modeFor({String? jobId, AssignedBikeEntity? bike}) {
    if (bike != null) return BackgroundTracking.bike;
    if (jobId != null) return BackgroundTracking.job;
    return BackgroundTracking.none;
  }

  // Starts continuous GPS tracking (with a foreground service for an active
  // job or an assigned company bike)
  Future<void> start({String? jobId}) async {
    final mode = _modeFor(jobId: jobId, bike: state.bike);

    if (_subscription != null && state.isBroadcasting && mode == _streamMode) {
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
    _streamMode = mode;
    _subscription = LocationService.instance
        .positionStream(background: mode, bikeLabel: state.bike?.label)
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
    _syncHeartbeat();
  }

  /// Tracks [bike] for as long as it stays assigned; null stops bike tracking.
  /// Called by [BikeTrackingSupervisor].
  Future<void> setBike(AssignedBikeEntity? bike) async {
    final previous = state.bike;
    if (previous?.id == bike?.id && previous?.label == bike?.label) return;

    state = state.copyWith(bike: bike, clearBike: bike == null);

    if (bike != null) {
      await start(jobId: state.jobId);
    } else if (state.jobId != null) {
      await start(jobId: state.jobId);
    } else {
      await stop();
    }
  }

  // Stops GPS stream and background service
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _streamMode = BackgroundTracking.none;
    _uploadThrottle?.cancel();
    _uploadThrottle = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _pendingUpload = null;
    state = state.copyWith(isBroadcasting: false, clearJobId: true);
  }

  /// Signed out, or not a rider: nothing may keep reporting a location.
  Future<void> stopAll() async {
    state = state.copyWith(clearBike: true);
    await stop();
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

  void _syncHeartbeat() {
    final wanted = state.isBroadcasting && state.bike != null;
    if (!wanted) {
      _heartbeat?.cancel();
      _heartbeat = null;
      return;
    }
    _heartbeat ??= Timer.periodic(_bikeHeartbeat, (_) => _beat());
  }

  /// The position stream only fires on movement, so a parked bike would
  /// otherwise report nothing for hours.
  Future<void> _beat() async {
    final since =
        _lastUploadAt == null ? null : DateTime.now().difference(_lastUploadAt!);
    if (since != null && since < _bikeHeartbeat - const Duration(seconds: 10)) {
      return;
    }

    final fix = await LocationService.instance.currentPosition(
      accuracy: LocationAccuracy.medium,
      timeout: const Duration(seconds: 15),
    );
    final position = fix ?? state.position;
    if (position == null) return;
    if (fix != null) state = state.copyWith(position: fix);
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
    _heartbeat?.cancel();
  }
}

/// The company bike assigned to the signed-in rider, or null.
@Riverpod(keepAlive: true)
Stream<AssignedBikeEntity?> riderAssignedBike(Ref ref) {
  final auth = ref.watch(authStateControllerProvider);
  if (auth is! AuthAuthenticated || auth.user.role != UserRole.rider) {
    return Stream.value(null);
  }
  return ref.watch(riderRepositoryProvider).watchAssignedBike();
}

/// Keeps GPS tracking running for as long as the signed-in rider holds a
/// company bike -- including while they are Offline or the app is in the
/// background -- and shuts everything down when they sign out.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.
@Riverpod(keepAlive: true)
class BikeTrackingSupervisor extends _$BikeTrackingSupervisor {
  @override
  void build() {
    final auth = ref.watch(authStateControllerProvider);
    final isRider = auth is AuthAuthenticated && auth.user.role == UserRole.rider;

    if (!isRider) {
      // Not while a sign-in is still resolving: the rider could be mid-job.
      if (auth is AuthUnauthenticated) {
        Future.microtask(() => ref.read(riderTrackingProvider.notifier).stopAll());
      }
      return;
    }

    ref.listen<AsyncValue<AssignedBikeEntity?>>(
      riderAssignedBikeProvider,
      (_, next) {
        if (!next.hasValue) return;
        final bike = next.value;
        Future.microtask(() => ref.read(riderTrackingProvider.notifier).setBike(bike));
      },
      fireImmediately: true,
    );
  }
}

// Calculates distance in meters from current rider position to target
double? riderDistanceTo(RiderTrackingState state, LatLng? target) {
  final from = state.latLng;
  if (from == null || target == null) return null;
  return GeoUtils.distanceMeters(from, target);
}
