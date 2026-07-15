import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/customer_entities.dart';

part 'customer_models.freezed.dart';
part 'customer_models.g.dart';

@freezed
abstract class BinModel with _$BinModel {
  const factory BinModel({
    required String id,
    required String serialNumber,
    required String type,
    required String size,
    required double fillLevelPercentage,
    String? scheduleFrequency,
    List<String>? pickupDays,
    String? verificationPhotoUrl,
    required DateTime registeredDate,
  }) = _BinModel;

  factory BinModel.fromJson(Map<String, dynamic> json) => _$BinModelFromJson(json);

  const BinModel._();

  BinEntity toEntity() => BinEntity(
        id: id,
        serialNumber: serialNumber,
        type: type,
        size: size,
        fillLevelPercentage: fillLevelPercentage,
        scheduleFrequency: scheduleFrequency,
        pickupDays: pickupDays,
        verificationPhotoUrl: verificationPhotoUrl,
        registeredDate: registeredDate,
      );

  factory BinModel.fromEntity(BinEntity entity) => BinModel(
        id: entity.id,
        serialNumber: entity.serialNumber,
        type: entity.type,
        size: entity.size,
        fillLevelPercentage: entity.fillLevelPercentage,
        scheduleFrequency: entity.scheduleFrequency,
        pickupDays: entity.pickupDays,
        verificationPhotoUrl: entity.verificationPhotoUrl,
        registeredDate: entity.registeredDate,
      );
}

@freezed
abstract class PickupRequestModel with _$PickupRequestModel {
  const factory PickupRequestModel({
    required String id,
    required List<String> binTypes,
    required DateTime date,
    required String timeSlot,
    required String location,
    String? instructions,
    required String status,
  }) = _PickupRequestModel;

  factory PickupRequestModel.fromJson(Map<String, dynamic> json) => _$PickupRequestModelFromJson(json);

  const PickupRequestModel._();

  PickupRequestEntity toEntity() => PickupRequestEntity(
        id: id,
        binTypes: binTypes,
        date: date,
        timeSlot: timeSlot,
        location: location,
        instructions: instructions,
        status: status,
      );

  factory PickupRequestModel.fromEntity(PickupRequestEntity entity) => PickupRequestModel(
        id: entity.id,
        binTypes: entity.binTypes,
        date: entity.date,
        timeSlot: entity.timeSlot,
        location: entity.location,
        instructions: entity.instructions,
        status: entity.status,
      );
}

@freezed
abstract class ServiceRecordModel with _$ServiceRecordModel {
  const factory ServiceRecordModel({
    required String id,
    required String title,
    required String type,
    required DateTime date,
    required String status,
    double? weightKg,
    double? co2OffsetKg,
    Map<String, double>? compositionPercentages,
    required double amountPaid,
    String? receiptNumber,
  }) = _ServiceRecordModel;

  factory ServiceRecordModel.fromJson(Map<String, dynamic> json) => _$ServiceRecordModelFromJson(json);

  const ServiceRecordModel._();

  ServiceRecordEntity toEntity() => ServiceRecordEntity(
        id: id,
        title: title,
        type: type,
        date: date,
        status: status,
        weightKg: weightKg,
        co2OffsetKg: co2OffsetKg,
        compositionPercentages: compositionPercentages,
        amountPaid: amountPaid,
        receiptNumber: receiptNumber,
      );

  factory ServiceRecordModel.fromEntity(ServiceRecordEntity entity) => ServiceRecordModel(
        id: entity.id,
        title: entity.title,
        type: entity.type,
        date: entity.date,
        status: entity.status,
        weightKg: entity.weightKg,
        co2OffsetKg: entity.co2OffsetKg,
        compositionPercentages: entity.compositionPercentages,
        amountPaid: entity.amountPaid,
        receiptNumber: entity.receiptNumber,
      );
}

@freezed
abstract class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    required String currentPlan,
    required double fee,
    required String status,
    required String paymentMethod,
    required double outstandingBalance,
    DateTime? nextPickupDate,
  }) = _SubscriptionModel;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => _$SubscriptionModelFromJson(json);

  const SubscriptionModel._();

  SubscriptionEntity toEntity() => SubscriptionEntity(
        currentPlan: currentPlan,
        fee: fee,
        status: status,
        paymentMethod: paymentMethod,
        outstandingBalance: outstandingBalance,
        nextPickupDate: nextPickupDate,
      );

  factory SubscriptionModel.fromEntity(SubscriptionEntity entity) => SubscriptionModel(
        currentPlan: entity.currentPlan,
        fee: entity.fee,
        status: entity.status,
        paymentMethod: entity.paymentMethod,
        outstandingBalance: entity.outstandingBalance,
        nextPickupDate: entity.nextPickupDate,
      );
}
