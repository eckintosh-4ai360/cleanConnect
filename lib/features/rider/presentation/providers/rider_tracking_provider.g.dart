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

String _$riderTrackingHash() => r'017fb508421f47632c7444828414b5145b4d79f5';

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
