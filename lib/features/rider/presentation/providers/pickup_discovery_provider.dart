import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/pickup_request_entity.dart';
import 'rider_providers.dart';
import 'rider_tracking_provider.dart';

part 'pickup_discovery_provider.g.dart';

/// A pickup on offer, with how far the rider is from it.
class NearbyPickup {
  final PickupRequestEntity pickup;

  /// Straight-line metres from the rider, or null when the rider or the
  /// request has no coordinates to measure between.
  final double? distanceMeters;

  const NearbyPickup({required this.pickup, this.distanceMeters});

  /// "820 m" / "2.4 km", or null when the distance is unknown.
  String? get distanceLabel =>
      distanceMeters == null ? null : GeoUtils.formatDistance(distanceMeters!);
}

/// What this rider may take, and why the rest is not on the list.
class PickupDiscovery {
  /// Open pickups within [radiusKm], nearest first. Requests with no
  /// coordinates come last: they cannot be measured, so they are never hidden.
  final List<NearbyPickup> pickups;

  /// Open pickups dropped for being too far away.
  final int outOfRangeCount;

  final double radiusKm;

  /// False when dispatch has no position for this rider. Nothing is filtered in
  /// that case — the list is not the place to punish a location problem — but
  /// the screen says so, because the server does scope the alerts that ring
  /// their phone.
  final bool riderLocated;

  const PickupDiscovery({
    required this.pickups,
    required this.outOfRangeCount,
    required this.radiusKm,
    required this.riderLocated,
  });
}

/// The radius the server dispatches in, so the rider's list and the alerts
/// their phone rings for cover the same ground.
@riverpod
Future<double> pickupDiscoveryRadiusKm(Ref ref) {
  return ref.watch(riderRepositoryProvider).getPickupDiscoveryRadiusKm();
}

/// Where the rider is, for scoping the pickup list.
///
/// The live GPS fix once this session has one; until then the position dispatch
/// last recorded for them, which is already on the profile row and so needs no
/// wait. Null means neither exists.
@riverpod
LatLng? riderOrigin(Ref ref) {
  final live = ref.watch(riderTrackingProvider).latLng;
  if (live != null) return live;
  return ref.watch(riderProfileProvider).value?.lastKnownPosition;
}

/// Open pickups, scoped to the ones close enough for this rider to serve.
///
/// A request in Tarkwa is no business of a rider in Accra: the server decides
/// that for push alerts (see 20260920140000_pickup_distance_discovery.sql), and
/// this is the same rule applied to the browsable list, against the rider's live
/// position rather than their last reported one.
@riverpod
PickupDiscovery nearbyPickups(Ref ref) {
  final radiusKm = ref.watch(pickupDiscoveryRadiusKmProvider).value ??
      MapConfig.defaultPickupDiscoveryRadiusKm;
  final open = ref.watch(availablePickupsProvider).value ??
      const <PickupRequestEntity>[];
  final origin = ref.watch(riderOriginProvider);

  if (origin == null) {
    return PickupDiscovery(
      pickups: [for (final p in open) NearbyPickup(pickup: p)],
      outOfRangeCount: 0,
      radiusKm: radiusKm,
      riderLocated: false,
    );
  }

  final radiusMeters = radiusKm * 1000;
  final inRange = <NearbyPickup>[];
  var outOfRange = 0;

  for (final pickup in open) {
    final destination = pickup.destination;
    if (destination == null) {
      // A legacy row whose address was never resolved to coordinates. It cannot
      // be placed, so it cannot be excluded either.
      inRange.add(NearbyPickup(pickup: pickup));
      continue;
    }

    final metres = GeoUtils.distanceMeters(origin, destination);
    if (metres > radiusMeters) {
      outOfRange++;
      continue;
    }
    inRange.add(NearbyPickup(pickup: pickup, distanceMeters: metres));
  }

  inRange.sort((a, b) {
    final da = a.distanceMeters;
    final db = b.distanceMeters;
    if (da == null && db == null) return 0;
    if (da == null) return 1; // unmeasurable ones sink to the bottom
    if (db == null) return -1;
    return da.compareTo(db);
  });

  return PickupDiscovery(
    pickups: inRange,
    outOfRangeCount: outOfRange,
    radiusKm: radiusKm,
    riderLocated: true,
  );
}
