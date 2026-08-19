import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/entities/incident_report_entity.dart';
import '../../domain/entities/pickup_tracking_entity.dart';
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

  Future<void> updateBin({
    required String binId,
    required String frequency,
    required List<String> pickupDays,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .updateBin(binId: binId, frequency: frequency, pickupDays: pickupDays);
  }

  Future<void> deleteBin(String binId) async {
    await ref.read(customerRepositoryProvider).deleteBin(binId);
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
    double surchargeAppliedPercentage = 0.0,
    double? locationLat,
    double? locationLng,
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
          surchargeAppliedPercentage: surchargeAppliedPercentage,
          locationLat: locationLat,
          locationLng: locationLng,
        );
  }

  Future<void> cancelPickup(String requestId) async {
    await ref.read(customerRepositoryProvider).cancelPickupRequest(requestId);
  }
}

/// Live rider position for one specific request -- what the tracking screen
/// opened from a booking watches.
@riverpod
class PickupTracking extends _$PickupTracking {
  @override
  Stream<PickupTrackingEntity?> build(String requestId) {
    return ref.watch(customerRepositoryProvider).watchPickupTracking(requestId);
  }

  /// Backfills coordinates on a legacy request whose location was a plain
  /// address, once the tracking screen has geocoded it.
  Future<void> setDestination(double latitude, double longitude) async {
    await ref.read(customerRepositoryProvider).setPickupDestination(
          requestId: requestId,
          latitude: latitude,
          longitude: longitude,
        );
  }
}

/// The request the customer should currently be tracking, if any. Backs the
/// "Track your pickup" banner on the dashboard.
@riverpod
class ActivePickupTracking extends _$ActivePickupTracking {
  @override
  Stream<PickupTrackingEntity?> build() {
    return ref.watch(customerRepositoryProvider).watchActivePickupTracking();
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

  Future<void> updateHousePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await ref
        .read(customerRepositoryProvider)
        .updateHousePhoto(bytes: bytes, fileName: fileName);
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

@riverpod
class CustomerIncidentReports extends _$CustomerIncidentReports {
  @override
  Stream<List<IncidentReportEntity>> build() {
    return ref.watch(customerRepositoryProvider).watchIncidentReports();
  }

  Future<IncidentReportEntity> submitReport({
    required String description,
    required String location,
    Uint8List? mediaBytes,
    String? mediaFileName,
    String? mediaType,
  }) async {
    return ref
        .read(customerRepositoryProvider)
        .submitIncidentReport(
          description: description,
          location: location,
          mediaBytes: mediaBytes,
          mediaFileName: mediaFileName,
          mediaType: mediaType,
        );
  }
}
