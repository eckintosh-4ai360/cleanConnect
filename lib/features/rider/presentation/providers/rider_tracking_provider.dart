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

/// Snapshot of the rider's own device location, plus whether it is currently
/// being broadcast to Supabase.
@immutable
class RiderTrackingState {
  final Position? position;
  final LocationAccess? access;
  final bool isBroadcasting;

  /// Job whose row is being mirrored, if any. Null means "profile only".
  final String? jobId;

  /// Last error seen while pushing a fix. Kept so the UI can show a quiet
  /// "reconnecting" hint rather than a blocking dialog -- a dropped upload is
  /// recoverable and the next fix retries in seconds.
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

  /// Heading in degrees. GPS reports -1 (or a meaningless value) when the
  /// device is stationary, so callers should treat null as "keep the last
  /// known bearing" rather than snapping the marker to north.
  double? get heading {
    final h = position?.heading;
    if (h == null || h < 0) return null;
    return h;
  }

  /// Ground speed in km/h, floored at zero -- some Android devices report a
  /// small negative speed when the fix is interpolated.
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

/// Owns the rider's GPS stream and mirrors each fix to Supabase.
///
/// This replaces the timer that used to nudge fake coordinates on the
/// navigation screen. There is exactly one of these per app session, so a rider
/// moving between the navigation screen and the route screen keeps a single
/// subscription and a single upload cadence rather than stacking them.
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

  /// Starts streaming. With [jobId] set, fixes are mirrored onto that pickup's
  /// row as well as the rider profile, and Android promotes the stream to a
  /// foreground service so tracking survives the screen locking.
  ///
  /// Safe to call repeatedly. Switching between two jobs only re-points the
  /// mirror target; switching between "no job" and "on a job" restarts the
  /// stream, because that is what changes the platform settings underneath it.
  Future<void> start({String? jobId}) async {
    if (state.isBroadcasting && state.jobId == jobId) return;

    // Whether we need a foreground service is decided by the presence of a job,
    // not its identity. Only when that flag is unchanged can we swap the target
    // without tearing the stream down -- otherwise the rider accepts a job and
    // the foreground service never starts, so tracking dies the moment they
    // lock the screen. That failure is invisible on the rider's own device and
    // only shows up as a frozen marker for dispatch and the customer.
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

    // Seed the map with whatever fix is available immediately so the camera
    // does not sit on the city fallback while the first stream event lands.
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

  /// Stops streaming and tears down the Android foreground service. Called when
  /// the rider ends a job or goes off duty -- not on every screen dispose, so
  /// navigating away from the map does not silently stop dispatch tracking.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _uploadThrottle?.cancel();
    _uploadThrottle = null;
    _pendingUpload = null;
    state = state.copyWith(isBroadcasting: false, clearJobId: true);
  }

  /// Re-runs the permission request after the rider returns from Settings.
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

  /// Throttles writes to [MapConfig.riderUploadInterval].
  ///
  /// The GPS stream fires far faster than dispatch needs while driving, and
  /// every write fans out over Realtime to the admin panel and the customer's
  /// tracking screen. The newest fix always wins -- a queued older one is
  /// replaced rather than sent late.
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
      // Non-fatal: the rider keeps navigating on-device and the next fix
      // retries. Surfacing it lets the UI show a "not syncing" indicator.
      debugPrint('RiderTracking: location upload failed - $e');
      state = state.copyWith(uploadError: 'Not syncing with dispatch');
    }
  }

  void _teardown() {
    _subscription?.cancel();
    _uploadThrottle?.cancel();
  }
}

/// Distance in metres from the rider's current fix to [target], or null when
/// there is no fix yet. Used for the arrival check on the navigation screen.
double? riderDistanceTo(RiderTrackingState state, LatLng? target) {
  final from = state.latLng;
  if (from == null || target == null) return null;
  return GeoUtils.distanceMeters(from, target);
}
