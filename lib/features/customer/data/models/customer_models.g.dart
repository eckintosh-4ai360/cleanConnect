// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BinModel _$BinModelFromJson(Map<String, dynamic> json) => _BinModel(
  id: json['id'] as String,
  serialNumber: json['serialNumber'] as String,
  type: json['type'] as String,
  size: json['size'] as String,
  fillLevelPercentage: (json['fillLevelPercentage'] as num).toDouble(),
  scheduleFrequency: json['scheduleFrequency'] as String?,
  pickupDays: (json['pickupDays'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  verificationPhotoUrl: json['verificationPhotoUrl'] as String?,
  registeredDate: DateTime.parse(json['registeredDate'] as String),
);

Map<String, dynamic> _$BinModelToJson(_BinModel instance) => <String, dynamic>{
  'id': instance.id,
  'serialNumber': instance.serialNumber,
  'type': instance.type,
  'size': instance.size,
  'fillLevelPercentage': instance.fillLevelPercentage,
  'scheduleFrequency': instance.scheduleFrequency,
  'pickupDays': instance.pickupDays,
  'verificationPhotoUrl': instance.verificationPhotoUrl,
  'registeredDate': instance.registeredDate.toIso8601String(),
};

_PickupRequestModel _$PickupRequestModelFromJson(Map<String, dynamic> json) =>
    _PickupRequestModel(
      id: json['id'] as String,
      binTypes: (json['binTypes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      date: DateTime.parse(json['date'] as String),
      timeSlot: json['timeSlot'] as String,
      location: json['location'] as String,
      instructions: json['instructions'] as String?,
      status: json['status'] as String,
    );

Map<String, dynamic> _$PickupRequestModelToJson(_PickupRequestModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'binTypes': instance.binTypes,
      'date': instance.date.toIso8601String(),
      'timeSlot': instance.timeSlot,
      'location': instance.location,
      'instructions': instance.instructions,
      'status': instance.status,
    };

_ServiceRecordModel _$ServiceRecordModelFromJson(Map<String, dynamic> json) =>
    _ServiceRecordModel(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      co2OffsetKg: (json['co2OffsetKg'] as num?)?.toDouble(),
      compositionPercentages:
          (json['compositionPercentages'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      receiptNumber: json['receiptNumber'] as String?,
    );

Map<String, dynamic> _$ServiceRecordModelToJson(_ServiceRecordModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'type': instance.type,
      'date': instance.date.toIso8601String(),
      'status': instance.status,
      'weightKg': instance.weightKg,
      'co2OffsetKg': instance.co2OffsetKg,
      'compositionPercentages': instance.compositionPercentages,
      'amountPaid': instance.amountPaid,
      'receiptNumber': instance.receiptNumber,
    };

_SubscriptionModel _$SubscriptionModelFromJson(Map<String, dynamic> json) =>
    _SubscriptionModel(
      currentPlan: json['currentPlan'] as String,
      fee: (json['fee'] as num).toDouble(),
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String,
      outstandingBalance: (json['outstandingBalance'] as num).toDouble(),
      nextPickupDate: json['nextPickupDate'] == null
          ? null
          : DateTime.parse(json['nextPickupDate'] as String),
    );

Map<String, dynamic> _$SubscriptionModelToJson(_SubscriptionModel instance) =>
    <String, dynamic>{
      'currentPlan': instance.currentPlan,
      'fee': instance.fee,
      'status': instance.status,
      'paymentMethod': instance.paymentMethod,
      'outstandingBalance': instance.outstandingBalance,
      'nextPickupDate': instance.nextPickupDate?.toIso8601String(),
    };
