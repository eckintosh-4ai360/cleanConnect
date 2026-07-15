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
  FutureOr<List<BinEntity>> build() async {
    return ref.watch(customerRepositoryProvider).getBins();
  }

  Future<void> registerNewBin({
    required String type,
    required String size,
    required String serialNumber,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(customerRepositoryProvider).registerBin(
            type: type,
            size: size,
            serialNumber: serialNumber,
            frequency: frequency,
            pickupDays: pickupDays,
            gpsLocation: gpsLocation,
            photoPath: photoPath,
          );
      return ref.read(customerRepositoryProvider).getBins();
    });
  }
}

@riverpod
class CustomerPickupRequests extends _$CustomerPickupRequests {
  @override
  FutureOr<List<PickupRequestEntity>> build() async {
    return ref.watch(customerRepositoryProvider).getPickupRequests();
  }

  Future<void> requestPickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    String? instructions,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(customerRepositoryProvider).schedulePickup(
            binTypes: binTypes,
            date: date,
            timeSlot: timeSlot,
            location: location,
            instructions: instructions,
          );
      return ref.read(customerRepositoryProvider).getPickupRequests();
    });
  }
}

@riverpod
class CustomerSubscription extends _$CustomerSubscription {
  @override
  FutureOr<SubscriptionEntity> build() async {
    return ref.watch(customerRepositoryProvider).getSubscription();
  }

  Future<void> changePlan({
    required String newPlan,
    required double fee,
    required String paymentMethod,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(customerRepositoryProvider).updateSubscription(
            newPlan: newPlan,
            fee: fee,
            paymentMethod: paymentMethod,
          );
      ref.invalidate(customerHistoryProvider); // Refresh history for potential new invoice
      return updated;
    });
  }

  Future<void> payBalance() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(customerRepositoryProvider).payOutstandingBalance();
      ref.invalidate(customerHistoryProvider); // Refresh history for payment confirmation
      return ref.read(customerRepositoryProvider).getSubscription();
    });
  }
}

@riverpod
class CustomerHistory extends _$CustomerHistory {
  @override
  FutureOr<List<ServiceRecordEntity>> build() async {
    return ref.watch(customerRepositoryProvider).getServiceHistory();
  }

  Future<void> submitProblem({
    required String category,
    required String description,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(customerRepositoryProvider).reportProblem(
            category: category,
            description: description,
          );
      return ref.read(customerRepositoryProvider).getServiceHistory();
    });
  }
}
