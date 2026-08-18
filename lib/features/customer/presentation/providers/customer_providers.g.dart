// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerRepository)
final customerRepositoryProvider = CustomerRepositoryProvider._();

final class CustomerRepositoryProvider
    extends
        $FunctionalProvider<
          CustomerRepository,
          CustomerRepository,
          CustomerRepository
        >
    with $Provider<CustomerRepository> {
  CustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerRepositoryHash();

  @$internal
  @override
  $ProviderElement<CustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerRepository create(Ref ref) {
    return customerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerRepository>(value),
    );
  }
}

String _$customerRepositoryHash() =>
    r'd0c3376392569ebb4d4fddb76a497ea55ed0cffa';

@ProviderFor(CustomerBins)
final customerBinsProvider = CustomerBinsProvider._();

final class CustomerBinsProvider
    extends $StreamNotifierProvider<CustomerBins, List<BinEntity>> {
  CustomerBinsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerBinsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerBinsHash();

  @$internal
  @override
  CustomerBins create() => CustomerBins();
}

String _$customerBinsHash() => r'2951eafc887443115a4f6908fe11fde9804026cf';

abstract class _$CustomerBins extends $StreamNotifier<List<BinEntity>> {
  Stream<List<BinEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<BinEntity>>, List<BinEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<BinEntity>>, List<BinEntity>>,
              AsyncValue<List<BinEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CustomerPickupRequests)
final customerPickupRequestsProvider = CustomerPickupRequestsProvider._();

final class CustomerPickupRequestsProvider
    extends
        $StreamNotifierProvider<
          CustomerPickupRequests,
          List<PickupRequestEntity>
        > {
  CustomerPickupRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerPickupRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerPickupRequestsHash();

  @$internal
  @override
  CustomerPickupRequests create() => CustomerPickupRequests();
}

String _$customerPickupRequestsHash() =>
    r'de24ae9070912e00681064904670b9b9f9cae9f7';

abstract class _$CustomerPickupRequests
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

/// Live rider position for one specific request -- what the tracking screen
/// opened from a booking watches.

@ProviderFor(PickupTracking)
final pickupTrackingProvider = PickupTrackingFamily._();

/// Live rider position for one specific request -- what the tracking screen
/// opened from a booking watches.
final class PickupTrackingProvider
    extends $StreamNotifierProvider<PickupTracking, PickupTrackingEntity?> {
  /// Live rider position for one specific request -- what the tracking screen
  /// opened from a booking watches.
  PickupTrackingProvider._({
    required PickupTrackingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pickupTrackingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pickupTrackingHash();

  @override
  String toString() {
    return r'pickupTrackingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PickupTracking create() => PickupTracking();

  @override
  bool operator ==(Object other) {
    return other is PickupTrackingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pickupTrackingHash() => r'3c28a4700bad831a8321d6d33f9c3957503eae12';

/// Live rider position for one specific request -- what the tracking screen
/// opened from a booking watches.

final class PickupTrackingFamily extends $Family
    with
        $ClassFamilyOverride<
          PickupTracking,
          AsyncValue<PickupTrackingEntity?>,
          PickupTrackingEntity?,
          Stream<PickupTrackingEntity?>,
          String
        > {
  PickupTrackingFamily._()
    : super(
        retry: null,
        name: r'pickupTrackingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live rider position for one specific request -- what the tracking screen
  /// opened from a booking watches.

  PickupTrackingProvider call(String requestId) =>
      PickupTrackingProvider._(argument: requestId, from: this);

  @override
  String toString() => r'pickupTrackingProvider';
}

/// Live rider position for one specific request -- what the tracking screen
/// opened from a booking watches.

abstract class _$PickupTracking extends $StreamNotifier<PickupTrackingEntity?> {
  late final _$args = ref.$arg as String;
  String get requestId => _$args;

  Stream<PickupTrackingEntity?> build(String requestId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PickupTrackingEntity?>, PickupTrackingEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PickupTrackingEntity?>,
                PickupTrackingEntity?
              >,
              AsyncValue<PickupTrackingEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The request the customer should currently be tracking, if any. Backs the
/// "Track your pickup" banner on the dashboard.

@ProviderFor(ActivePickupTracking)
final activePickupTrackingProvider = ActivePickupTrackingProvider._();

/// The request the customer should currently be tracking, if any. Backs the
/// "Track your pickup" banner on the dashboard.
final class ActivePickupTrackingProvider
    extends
        $StreamNotifierProvider<ActivePickupTracking, PickupTrackingEntity?> {
  /// The request the customer should currently be tracking, if any. Backs the
  /// "Track your pickup" banner on the dashboard.
  ActivePickupTrackingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activePickupTrackingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activePickupTrackingHash();

  @$internal
  @override
  ActivePickupTracking create() => ActivePickupTracking();
}

String _$activePickupTrackingHash() =>
    r'680b90b6f64f4e4e8a94552ca1f0da5f968fd8d1';

/// The request the customer should currently be tracking, if any. Backs the
/// "Track your pickup" banner on the dashboard.

abstract class _$ActivePickupTracking
    extends $StreamNotifier<PickupTrackingEntity?> {
  Stream<PickupTrackingEntity?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PickupTrackingEntity?>, PickupTrackingEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PickupTrackingEntity?>,
                PickupTrackingEntity?
              >,
              AsyncValue<PickupTrackingEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CustomerPricingPlans)
final customerPricingPlansProvider = CustomerPricingPlansProvider._();

final class CustomerPricingPlansProvider
    extends
        $StreamNotifierProvider<CustomerPricingPlans, List<PricingPlanEntity>> {
  CustomerPricingPlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerPricingPlansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerPricingPlansHash();

  @$internal
  @override
  CustomerPricingPlans create() => CustomerPricingPlans();
}

String _$customerPricingPlansHash() =>
    r'296bfb1272a5c9a1be907c306c21b7e3ce86e1df';

abstract class _$CustomerPricingPlans
    extends $StreamNotifier<List<PricingPlanEntity>> {
  Stream<List<PricingPlanEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PricingPlanEntity>>,
              List<PricingPlanEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PricingPlanEntity>>,
                List<PricingPlanEntity>
              >,
              AsyncValue<List<PricingPlanEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CustomerSubscription)
final customerSubscriptionProvider = CustomerSubscriptionProvider._();

final class CustomerSubscriptionProvider
    extends $StreamNotifierProvider<CustomerSubscription, SubscriptionEntity> {
  CustomerSubscriptionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerSubscriptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerSubscriptionHash();

  @$internal
  @override
  CustomerSubscription create() => CustomerSubscription();
}

String _$customerSubscriptionHash() =>
    r'f6a8650f0c053673027c898e39af4c95d03baeb9';

abstract class _$CustomerSubscription
    extends $StreamNotifier<SubscriptionEntity> {
  Stream<SubscriptionEntity> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SubscriptionEntity>, SubscriptionEntity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SubscriptionEntity>, SubscriptionEntity>,
              AsyncValue<SubscriptionEntity>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CustomerHistory)
final customerHistoryProvider = CustomerHistoryProvider._();

final class CustomerHistoryProvider
    extends
        $StreamNotifierProvider<CustomerHistory, List<ServiceRecordEntity>> {
  CustomerHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerHistoryHash();

  @$internal
  @override
  CustomerHistory create() => CustomerHistory();
}

String _$customerHistoryHash() => r'3be04df8c9164993e2f8c83e6106a458e865b57a';

abstract class _$CustomerHistory
    extends $StreamNotifier<List<ServiceRecordEntity>> {
  Stream<List<ServiceRecordEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ServiceRecordEntity>>,
              List<ServiceRecordEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ServiceRecordEntity>>,
                List<ServiceRecordEntity>
              >,
              AsyncValue<List<ServiceRecordEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CustomerIncidentReports)
final customerIncidentReportsProvider = CustomerIncidentReportsProvider._();

final class CustomerIncidentReportsProvider
    extends
        $StreamNotifierProvider<
          CustomerIncidentReports,
          List<IncidentReportEntity>
        > {
  CustomerIncidentReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerIncidentReportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerIncidentReportsHash();

  @$internal
  @override
  CustomerIncidentReports create() => CustomerIncidentReports();
}

String _$customerIncidentReportsHash() =>
    r'fa8adda34c65f91b6057d5463af715d115952ae7';

abstract class _$CustomerIncidentReports
    extends $StreamNotifier<List<IncidentReportEntity>> {
  Stream<List<IncidentReportEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<IncidentReportEntity>>,
              List<IncidentReportEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<IncidentReportEntity>>,
                List<IncidentReportEntity>
              >,
              AsyncValue<List<IncidentReportEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
