// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_discovery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The radius the server dispatches in, so the rider's list and the alerts
/// their phone rings for cover the same ground.

@ProviderFor(pickupDiscoveryRadiusKm)
final pickupDiscoveryRadiusKmProvider = PickupDiscoveryRadiusKmProvider._();

/// The radius the server dispatches in, so the rider's list and the alerts
/// their phone rings for cover the same ground.

final class PickupDiscoveryRadiusKmProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The radius the server dispatches in, so the rider's list and the alerts
  /// their phone rings for cover the same ground.
  PickupDiscoveryRadiusKmProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pickupDiscoveryRadiusKmProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pickupDiscoveryRadiusKmHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return pickupDiscoveryRadiusKm(ref);
  }
}

String _$pickupDiscoveryRadiusKmHash() =>
    r'4006a5afb0dde9280687cad529c0872f58aaac51';

/// Where the rider is, for scoping the pickup list.
///
/// The live GPS fix once this session has one; until then the position dispatch
/// last recorded for them, which is already on the profile row and so needs no
/// wait. Null means neither exists.

@ProviderFor(riderOrigin)
final riderOriginProvider = RiderOriginProvider._();

/// Where the rider is, for scoping the pickup list.
///
/// The live GPS fix once this session has one; until then the position dispatch
/// last recorded for them, which is already on the profile row and so needs no
/// wait. Null means neither exists.

final class RiderOriginProvider
    extends $FunctionalProvider<LatLng?, LatLng?, LatLng?>
    with $Provider<LatLng?> {
  /// Where the rider is, for scoping the pickup list.
  ///
  /// The live GPS fix once this session has one; until then the position dispatch
  /// last recorded for them, which is already on the profile row and so needs no
  /// wait. Null means neither exists.
  RiderOriginProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderOriginProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderOriginHash();

  @$internal
  @override
  $ProviderElement<LatLng?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LatLng? create(Ref ref) {
    return riderOrigin(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LatLng? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LatLng?>(value),
    );
  }
}

String _$riderOriginHash() => r'3834382c0536bf7633e2691173856c549b61c6c8';

/// Open pickups, scoped to the ones close enough for this rider to serve.
///
/// A request in Tarkwa is no business of a rider in Accra: the server decides
/// that for push alerts (see 20260920140000_pickup_distance_discovery.sql), and
/// this is the same rule applied to the browsable list, against the rider's live
/// position rather than their last reported one.

@ProviderFor(nearbyPickups)
final nearbyPickupsProvider = NearbyPickupsProvider._();

/// Open pickups, scoped to the ones close enough for this rider to serve.
///
/// A request in Tarkwa is no business of a rider in Accra: the server decides
/// that for push alerts (see 20260920140000_pickup_distance_discovery.sql), and
/// this is the same rule applied to the browsable list, against the rider's live
/// position rather than their last reported one.

final class NearbyPickupsProvider
    extends
        $FunctionalProvider<PickupDiscovery, PickupDiscovery, PickupDiscovery>
    with $Provider<PickupDiscovery> {
  /// Open pickups, scoped to the ones close enough for this rider to serve.
  ///
  /// A request in Tarkwa is no business of a rider in Accra: the server decides
  /// that for push alerts (see 20260920140000_pickup_distance_discovery.sql), and
  /// this is the same rule applied to the browsable list, against the rider's live
  /// position rather than their last reported one.
  NearbyPickupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nearbyPickupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearbyPickupsHash();

  @$internal
  @override
  $ProviderElement<PickupDiscovery> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PickupDiscovery create(Ref ref) {
    return nearbyPickups(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PickupDiscovery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PickupDiscovery>(value),
    );
  }
}

String _$nearbyPickupsHash() => r'bd14730897dd5900b2556e187a315c989117131a';
