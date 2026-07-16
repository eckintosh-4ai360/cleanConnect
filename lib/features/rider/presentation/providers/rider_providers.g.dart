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
    extends $AsyncNotifierProvider<RiderProfile, RiderEntity> {
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

String _$riderProfileHash() => r'414b1341dd001f1a1ec8a4edf6908f3696950637';

abstract class _$RiderProfile extends $AsyncNotifier<RiderEntity> {
  FutureOr<RiderEntity> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RiderEntity>, RiderEntity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RiderEntity>, RiderEntity>,
              AsyncValue<RiderEntity>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RiderActiveRoute)
final riderActiveRouteProvider = RiderActiveRouteProvider._();

final class RiderActiveRouteProvider
    extends $AsyncNotifierProvider<RiderActiveRoute, ActiveRouteEntity?> {
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

String _$riderActiveRouteHash() => r'71d169b828239afde880d66ebf26706185055f31';

abstract class _$RiderActiveRoute extends $AsyncNotifier<ActiveRouteEntity?> {
  FutureOr<ActiveRouteEntity?> build();
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
        $AsyncNotifierProvider<
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
    r'c5e2b2d2bde3bce1565a0896b5f2a1810b778d2f';

abstract class _$RiderCollectionHistory
    extends $AsyncNotifier<List<CollectionLogEntity>> {
  FutureOr<List<CollectionLogEntity>> build();
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
    extends $AsyncNotifierProvider<RiderPerformance, RiderPerformanceEntity> {
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

String _$riderPerformanceHash() => r'3611c0041b809b421cb2b772e68504e589056ed9';

abstract class _$RiderPerformance
    extends $AsyncNotifier<RiderPerformanceEntity> {
  FutureOr<RiderPerformanceEntity> build();
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
        $AsyncNotifierProvider<
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
    r'18ca25e46c6c3975290f1e38932228c284743f06';

abstract class _$RiderNotifications
    extends $AsyncNotifier<List<RiderNotificationEntity>> {
  FutureOr<List<RiderNotificationEntity>> build();
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
