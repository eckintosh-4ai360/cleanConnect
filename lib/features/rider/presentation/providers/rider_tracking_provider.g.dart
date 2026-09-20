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

String _$riderTrackingHash() => r'0aed45c994fdbfe5b87f7819b2bcb32cadf5518d';

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

/// Keeps a rider's location flowing to dispatch for exactly as long as it
/// should, and shuts everything down when they sign out.
///
/// Two independent reasons to track, in descending strength:
///
///  * a company bike is assigned -- tracked continuously and in the background,
///    even while the rider is Offline, because the bike is company property;
///  * the rider is simply on duty -- a coarse, foreground-only presence fix, so
///    distance-scoped dispatch can tell whether a new request is near them.
///    A rider it cannot place gets offered nothing, so going Offline is what
///    turns this off, and nothing else.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.

@ProviderFor(RiderLocationSupervisor)
final riderLocationSupervisorProvider = RiderLocationSupervisorProvider._();

/// Keeps a rider's location flowing to dispatch for exactly as long as it
/// should, and shuts everything down when they sign out.
///
/// Two independent reasons to track, in descending strength:
///
///  * a company bike is assigned -- tracked continuously and in the background,
///    even while the rider is Offline, because the bike is company property;
///  * the rider is simply on duty -- a coarse, foreground-only presence fix, so
///    distance-scoped dispatch can tell whether a new request is near them.
///    A rider it cannot place gets offered nothing, so going Offline is what
///    turns this off, and nothing else.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.
final class RiderLocationSupervisorProvider
    extends $NotifierProvider<RiderLocationSupervisor, void> {
  /// Keeps a rider's location flowing to dispatch for exactly as long as it
  /// should, and shuts everything down when they sign out.
  ///
  /// Two independent reasons to track, in descending strength:
  ///
  ///  * a company bike is assigned -- tracked continuously and in the background,
  ///    even while the rider is Offline, because the bike is company property;
  ///  * the rider is simply on duty -- a coarse, foreground-only presence fix, so
  ///    distance-scoped dispatch can tell whether a new request is near them.
  ///    A rider it cannot place gets offered nothing, so going Offline is what
  ///    turns this off, and nothing else.
  ///
  /// Watched once from the app root so it runs regardless of which screen the
  /// rider is on.
  RiderLocationSupervisorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderLocationSupervisorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderLocationSupervisorHash();

  @$internal
  @override
  RiderLocationSupervisor create() => RiderLocationSupervisor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$riderLocationSupervisorHash() =>
    r'8fe1ccd074a8e689cc0e452488ca4ecae9099a2a';

/// Keeps a rider's location flowing to dispatch for exactly as long as it
/// should, and shuts everything down when they sign out.
///
/// Two independent reasons to track, in descending strength:
///
///  * a company bike is assigned -- tracked continuously and in the background,
///    even while the rider is Offline, because the bike is company property;
///  * the rider is simply on duty -- a coarse, foreground-only presence fix, so
///    distance-scoped dispatch can tell whether a new request is near them.
///    A rider it cannot place gets offered nothing, so going Offline is what
///    turns this off, and nothing else.
///
/// Watched once from the app root so it runs regardless of which screen the
/// rider is on.

abstract class _$RiderLocationSupervisor extends $Notifier<void> {
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
