import 'dart:typed_data';

import '../entities/customer_entities.dart';
import '../entities/incident_report_entity.dart';
import '../entities/pickup_tracking_entity.dart';

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
    double originalAmount = 0.0,
    double discountAppliedPercentage = 0.0,
    double surchargeAppliedPercentage = 0.0,
    double? locationLat,
    double? locationLng,
  });

  /// Live position of the rider assigned to [requestId], updated over Realtime.
  Stream<PickupTrackingEntity?> watchPickupTracking(String requestId);

  /// The request the customer should currently be watching -- the one that is
  /// accepted or in progress. Null when nothing is active.
  Stream<PickupTrackingEntity?> watchActivePickupTracking();

  /// Attaches coordinates to a request that was created without them, so the
  /// tracking map has a destination to plot.
  Future<void> setPickupDestination({
    required String requestId,
    required double latitude,
    required double longitude,
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

  Future<void> updateHousePhoto({
    required Uint8List bytes,
    required String fileName,
  });

  Future<void> reportProblem({
    required String category,
    required String description,
  });

  Stream<List<IncidentReportEntity>> watchIncidentReports();

  Future<IncidentReportEntity> submitIncidentReport({
    required String description,
    required String location,
    Uint8List? mediaBytes,
    String? mediaFileName,
    String? mediaType,
  });
}
