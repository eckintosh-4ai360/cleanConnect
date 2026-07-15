import '../entities/customer_entities.dart';

abstract class CustomerRepository {
  Future<List<BinEntity>> getBins();

  Future<BinEntity> registerBin({
    required String type,
    required String size,
    required String serialNumber,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  });

  Future<List<PickupRequestEntity>> getPickupRequests();

  Future<PickupRequestEntity> schedulePickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    String? instructions,
  });

  Future<List<ServiceRecordEntity>> getServiceHistory();

  Future<SubscriptionEntity> getSubscription();

  Future<SubscriptionEntity> updateSubscription({
    required String newPlan,
    required double fee,
    required String paymentMethod,
  });

  Future<void> payOutstandingBalance();

  Future<void> reportProblem({
    required String category,
    required String description,
  });
}
