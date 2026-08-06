import '../entities/customer_entities.dart';

abstract class CustomerRepository {
  Stream<List<BinEntity>> watchBins();
  Future<List<BinEntity>> getBins();

  Future<BinEntity> registerBin({
    required String type,
    required String size,
    required String frequency,
    required List<String> pickupDays,
    required String gpsLocation,
    String? photoPath,
  });

  Future<void> requestCompanyBin({
    required String type,
    required String size,
    required String gpsLocation,
  });

  Stream<List<PickupRequestEntity>> watchPickupRequests();
  Future<List<PickupRequestEntity>> getPickupRequests();

  Future<PickupRequestEntity> schedulePickup({
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    required double amountPaid,
    required String paymentMethod,
    String? instructions,
  });

  Stream<List<ServiceRecordEntity>> watchServiceHistory();
  Future<List<ServiceRecordEntity>> getServiceHistory();

  Stream<SubscriptionEntity> watchSubscription();
  Future<SubscriptionEntity> getSubscription();

  Stream<List<PricingPlanEntity>> watchPricingPlans();

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
