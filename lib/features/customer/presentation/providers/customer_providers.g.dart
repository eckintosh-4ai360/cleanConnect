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
    extends $AsyncNotifierProvider<CustomerBins, List<BinEntity>> {
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

String _$customerBinsHash() => r'339f7cd4b3c8f268c0bf51dcc751e620ff908b03';

abstract class _$CustomerBins extends $AsyncNotifier<List<BinEntity>> {
  FutureOr<List<BinEntity>> build();
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
        $AsyncNotifierProvider<
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
    r'2a58128346bfadd1ff14a16097d7d7c4f1eff549';

abstract class _$CustomerPickupRequests
    extends $AsyncNotifier<List<PickupRequestEntity>> {
  FutureOr<List<PickupRequestEntity>> build();
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

@ProviderFor(CustomerSubscription)
final customerSubscriptionProvider = CustomerSubscriptionProvider._();

final class CustomerSubscriptionProvider
    extends $AsyncNotifierProvider<CustomerSubscription, SubscriptionEntity> {
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
    r'bf1ad37f081b046eff850de5b9a39e58f6d7c6e5';

abstract class _$CustomerSubscription
    extends $AsyncNotifier<SubscriptionEntity> {
  FutureOr<SubscriptionEntity> build();
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
    extends $AsyncNotifierProvider<CustomerHistory, List<ServiceRecordEntity>> {
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

String _$customerHistoryHash() => r'c0d323447a04bc26ddd0cbdc7eb72ecf3f88168e';

abstract class _$CustomerHistory
    extends $AsyncNotifier<List<ServiceRecordEntity>> {
  FutureOr<List<ServiceRecordEntity>> build();
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
