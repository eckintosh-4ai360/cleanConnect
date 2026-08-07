import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../data/repositories/customer_repository_impl.dart';

part 'customer_providers.g.dart';

@riverpod
CustomerRepository customerRepository(Ref ref) {
  return CustomerRepositoryImpl();
}

@riverpod
class CustomerBins extends _$CustomerBins {
  @override
  Stream<List<BinEntity>> build() {
    return ref.watch(customerRepositoryProvider).watchBins();
  }

  Future<BinEntity> registerNewBin({
    required String type,
    required String size,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  }) async {
    return ref
        .read(customerRepositoryProvider)
        .registerBin(
          type: type,
          size: size,
          frequency: frequency,
          pickupDays: pickupDays,
          gpsLocation: gpsLocation,
          photoPath: photoPath,
        );
  }

  Future<void> requestCompanyBin({
    required String type,
    required String size,
    required String gpsLocation,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .requestCompanyBin(
          type: type,
          size: size,
          gpsLocation: gpsLocation,
        );
  }
}

@riverpod
class CustomerPickupRequests extends _$CustomerPickupRequests {
  @override
  Stream<List<PickupRequestEntity>> build() {
    return ref.watch(customerRepositoryProvider).watchPickupRequests();
  }

  Future<void> requestPickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    required double amountPaid,
    required String paymentMethod,
    String? instructions,
    double originalAmount = 0.0,
    double discountAppliedPercentage = 0.0,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .schedulePickup(
          binTypes: binTypes,
          date: date,
          timeSlot: timeSlot,
          location: location,
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
          instructions: instructions,
          originalAmount: originalAmount,
          discountAppliedPercentage: discountAppliedPercentage,
        );
  }
}

@riverpod
class CustomerPricingPlans extends _$CustomerPricingPlans {
  @override
  Stream<List<PricingPlanEntity>> build() {
    return ref.watch(customerRepositoryProvider).watchPricingPlans();
  }
}

@riverpod
class CustomerSubscription extends _$CustomerSubscription {
  @override
  Stream<SubscriptionEntity> build() {
    return ref.watch(customerRepositoryProvider).watchSubscription();
  }

  Future<void> changePlan({
    required String newPlan,
    required double fee,
    required String paymentMethod,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .updateSubscription(
          newPlan: newPlan,
          fee: fee,
          paymentMethod: paymentMethod,
        );
  }

  Future<void> payBalance() async {
    await ref.read(customerRepositoryProvider).payOutstandingBalance();
  }
}

@riverpod
class CustomerHistory extends _$CustomerHistory {
  @override
  Stream<List<ServiceRecordEntity>> build() {
    return ref.watch(customerRepositoryProvider).watchServiceHistory();
  }

  Future<void> submitProblem({
    required String category,
    required String description,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .reportProblem(category: category, description: description);
  }
}
