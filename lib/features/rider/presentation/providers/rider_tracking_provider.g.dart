// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_tracking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the rider's GPS stream and mirrors each fix to Supabase.
///
/// This replaces the timer that used to nudge fake coordinates on the
/// navigation screen. There is exactly one of these per app session, so a rider
/// moving between the navigation screen and the route screen keeps a single
/// subscription and a single upload cadence rather than stacking them.

@ProviderFor(RiderTracking)
final riderTrackingProvider = RiderTrackingProvider._();

/// Owns the rider's GPS stream and mirrors each fix to Supabase.
///
/// This replaces the timer that used to nudge fake coordinates on the
/// navigation screen. There is exactly one of these per app session, so a rider
/// moving between the navigation screen and the route screen keeps a single
/// subscription and a single upload cadence rather than stacking them.
final class RiderTrackingProvider
    extends $NotifierProvider<RiderTracking, RiderTrackingState> {
  /// Owns the rider's GPS stream and mirrors each fix to Supabase.
  ///
  /// This replaces the timer that used to nudge fake coordinates on the
  /// navigation screen. There is exactly one of these per app session, so a rider
  /// moving between the navigation screen and the route screen keeps a single
  /// subscription and a single upload cadence rather than stacking them.
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

String _$riderTrackingHash() => r'8ff45bb2a25f1497034cfe75737d43a3bf218aac';

/// Owns the rider's GPS stream and mirrors each fix to Supabase.
///
/// This replaces the timer that used to nudge fake coordinates on the
/// navigation screen. There is exactly one of these per app session, so a rider
/// moving between the navigation screen and the route screen keeps a single
/// subscription and a single upload cadence rather than stacking them.

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
