// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_tracking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams rider GPS updates and broadcasts location to Supabase

@ProviderFor(RiderTracking)
final riderTrackingProvider = RiderTrackingProvider._();

/// Streams rider GPS updates and broadcasts location to Supabase
final class RiderTrackingProvider
    extends $NotifierProvider<RiderTracking, RiderTrackingState> {
  /// Streams rider GPS updates and broadcasts location to Supabase
  RiderTrackingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderTrackingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderTrackingHash();

  @$internal
  @override
  RiderTracking create() => RiderTracking();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RiderTrackingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RiderTrackingState>(value),
    );
  }
}

String _$riderTrackingHash() => r'3bd8e96e2135822b90c1038a65321032e188611d';

/// Streams rider GPS updates and broadcasts location to Supabase

abstract class _$RiderTracking extends $Notifier<RiderTrackingState> {
  RiderTrackingState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RiderTrackingState, RiderTrackingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RiderTrackingState, RiderTrackingState>,
              RiderTrackingState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The company bike assigned to the signed-in rider, or null.

@ProviderFor(riderAssignedBike)
final riderAssignedBikeProvider = RiderAssignedBikeProvider._();

/// The company bike assigned to the signed-in rider, or null.

final class RiderAssignedBikeProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssignedBikeEntity?>,
          AssignedBikeEntity?,
          Stream<AssignedBikeEntity?>
        >
    with
        $FutureModifier<AssignedBikeEntity?>,
        $StreamProvider<AssignedBikeEntity?> {
  /// The company bike assigned to the signed-in rider, or null.
  RiderAssignedBikeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderAssignedBikeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderAssignedBikeHash();

  @$internal
  @override
  $StreamProviderElement<AssignedBikeEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AssignedBikeEntity?> create(Ref ref) {
    return riderAssignedBike(ref);
  }
}

String _$riderAssignedBikeHash() => r'89f104a09d8fd0af4739dde6ca72e2c488de4053';

/// Keeps GPS tracking running for as long as the signed-in rider holds a
/// company bike -- including while they are Offline or the app is in the
/// background -- and shuts everything down when they sign out.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.

@ProviderFor(BikeTrackingSupervisor)
final bikeTrackingSupervisorProvider = BikeTrackingSupervisorProvider._();

/// Keeps GPS tracking running for as long as the signed-in rider holds a
/// company bike -- including while they are Offline or the app is in the
/// background -- and shuts everything down when they sign out.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.
final class BikeTrackingSupervisorProvider
    extends $NotifierProvider<BikeTrackingSupervisor, void> {
  /// Keeps GPS tracking running for as long as the signed-in rider holds a
  /// company bike -- including while they are Offline or the app is in the
  /// background -- and shuts everything down when they sign out.
  ///
  /// Watched once from the app root so it runs regardless of which screen the
  /// rider is on.
  BikeTrackingSupervisorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bikeTrackingSupervisorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bikeTrackingSupervisorHash();

  @$internal
  @override
  BikeTrackingSupervisor create() => BikeTrackingSupervisor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$bikeTrackingSupervisorHash() =>
    r'aac496ed22f1d921767377c1d6451f43cfc3488b';

/// Keeps GPS tracking running for as long as the signed-in rider holds a
/// company bike -- including while they are Offline or the app is in the
/// background -- and shuts everything down when they sign out.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.

abstract class _$BikeTrackingSupervisor extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
