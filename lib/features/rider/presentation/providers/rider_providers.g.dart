// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(riderRepository)
final riderRepositoryProvider = RiderRepositoryProvider._();

final class RiderRepositoryProvider
    extends
        $FunctionalProvider<RiderRepository, RiderRepository, RiderRepository>
    with $Provider<RiderRepository> {
  RiderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderRepositoryHash();

  @$internal
  @override
  $ProviderElement<RiderRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RiderRepository create(Ref ref) {
    return riderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RiderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RiderRepository>(value),
    );
  }
}

String _$riderRepositoryHash() => r'65f496f9a2da583de6644786f2e138350e8764a9';

@ProviderFor(RiderProfile)
final riderProfileProvider = RiderProfileProvider._();

final class RiderProfileProvider
    extends $StreamNotifierProvider<RiderProfile, RiderEntity?> {
  RiderProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderProfileHash();

  @$internal
  @override
  RiderProfile create() => RiderProfile();
}

String _$riderProfileHash() => r'a5e5b01f1cf7dca2f4f1d08ce331b935f99dedd1';

abstract class _$RiderProfile extends $StreamNotifier<RiderEntity?> {
  Stream<RiderEntity?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RiderEntity?>, RiderEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RiderEntity?>, RiderEntity?>,
              AsyncValue<RiderEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RiderActiveRoute)
final riderActiveRouteProvider = RiderActiveRouteProvider._();

final class RiderActiveRouteProvider
    extends $StreamNotifierProvider<RiderActiveRoute, ActiveRouteEntity?> {
  RiderActiveRouteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderActiveRouteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderActiveRouteHash();

  @$internal
  @override
  RiderActiveRoute create() => RiderActiveRoute();
}

String _$riderActiveRouteHash() => r'66bfebdcf6a1dee9fb09bed6271fdf47d36319e8';

abstract class _$RiderActiveRoute extends $StreamNotifier<ActiveRouteEntity?> {
  Stream<ActiveRouteEntity?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActiveRouteEntity?>, ActiveRouteEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActiveRouteEntity?>, ActiveRouteEntity?>,
              AsyncValue<ActiveRouteEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RiderCollectionHistory)
final riderCollectionHistoryProvider = RiderCollectionHistoryProvider._();

final class RiderCollectionHistoryProvider
    extends
        $StreamNotifierProvider<
          RiderCollectionHistory,
          List<CollectionLogEntity>
        > {
  RiderCollectionHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderCollectionHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderCollectionHistoryHash();

  @$internal
  @override
  RiderCollectionHistory create() => RiderCollectionHistory();
}

String _$riderCollectionHistoryHash() =>
    r'30f7aaf93e3314639b8274a7daeeb3acc933cefb';

abstract class _$RiderCollectionHistory
    extends $StreamNotifier<List<CollectionLogEntity>> {
  Stream<List<CollectionLogEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CollectionLogEntity>>,
              List<CollectionLogEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CollectionLogEntity>>,
                List<CollectionLogEntity>
              >,
              AsyncValue<List<CollectionLogEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RiderPerformance)
final riderPerformanceProvider = RiderPerformanceProvider._();

final class RiderPerformanceProvider
    extends $StreamNotifierProvider<RiderPerformance, RiderPerformanceEntity> {
  RiderPerformanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderPerformanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderPerformanceHash();

  @$internal
  @override
  RiderPerformance create() => RiderPerformance();
}

String _$riderPerformanceHash() => r'd52148bd5249fc1eeac8647d13ac6944b1298648';

abstract class _$RiderPerformance
    extends $StreamNotifier<RiderPerformanceEntity> {
  Stream<RiderPerformanceEntity> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<RiderPerformanceEntity>, RiderPerformanceEntity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<RiderPerformanceEntity>,
                RiderPerformanceEntity
              >,
              AsyncValue<RiderPerformanceEntity>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RiderNotifications)
final riderNotificationsProvider = RiderNotificationsProvider._();

final class RiderNotificationsProvider
    extends
        $StreamNotifierProvider<
          RiderNotifications,
          List<RiderNotificationEntity>
        > {
  RiderNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderNotificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderNotificationsHash();

  @$internal
  @override
  RiderNotifications create() => RiderNotifications();
}

String _$riderNotificationsHash() =>
    r'7b15af80d7a3f7fba09d00a6ebd4f89e076f386e';

abstract class _$RiderNotifications
    extends $StreamNotifier<List<RiderNotificationEntity>> {
  Stream<List<RiderNotificationEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RiderNotificationEntity>>,
              List<RiderNotificationEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RiderNotificationEntity>>,
                List<RiderNotificationEntity>
              >,
              AsyncValue<List<RiderNotificationEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AvailablePickups)
final availablePickupsProvider = AvailablePickupsProvider._();

final class AvailablePickupsProvider
    extends
        $StreamNotifierProvider<AvailablePickups, List<PickupRequestEntity>> {
  AvailablePickupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availablePickupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availablePickupsHash();

  @$internal
  @override
  AvailablePickups create() => AvailablePickups();
}

String _$availablePickupsHash() => r'68819a5ef273b141b3182e4a4474b2d32dc29f77';

abstract class _$AvailablePickups
    extends $StreamNotifier<List<PickupRequestEntity>> {
  Stream<List<PickupRequestEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PickupRequestEntity>>,
              List<PickupRequestEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PickupRequestEntity>>,
                List<PickupRequestEntity>
              >,
              AsyncValue<List<PickupRequestEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
