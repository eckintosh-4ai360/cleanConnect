class BinEntity {
  final String id;
  final String serialNumber;
  final String type; // 'general', 'recycling', 'organic'
  final String size; // '120L', '240L', '360L'
  final double fillLevelPercentage; // 0.0 to 1.0 (e.g. 0.45 = 45%)
  final String? scheduleFrequency; // 'Weekly', 'Bi-weekly', 'Monthly'
  final List<String>? pickupDays; // ['Monday', 'Thursday']
  final String? verificationPhotoUrl;
  final DateTime registeredDate;

  const BinEntity({
    required this.id,
    required this.serialNumber,
    required this.type,
    required this.size,
    required this.fillLevelPercentage,
    this.scheduleFrequency,
    this.pickupDays,
    this.verificationPhotoUrl,
    required this.registeredDate,
  });

  BinEntity copyWith({
    String? id,
    String? serialNumber,
    String? type,
    String? size,
    double? fillLevelPercentage,
    String? scheduleFrequency,
    List<String>? pickupDays,
    String? verificationPhotoUrl,
    DateTime? registeredDate,
  }) {
    return BinEntity(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      type: type ?? this.type,
      size: size ?? this.size,
      fillLevelPercentage: fillLevelPercentage ?? this.fillLevelPercentage,
      scheduleFrequency: scheduleFrequency ?? this.scheduleFrequency,
      pickupDays: pickupDays ?? this.pickupDays,
      verificationPhotoUrl: verificationPhotoUrl ?? this.verificationPhotoUrl,
      registeredDate: registeredDate ?? this.registeredDate,
    );
  }
}

class PickupRequestEntity {
  final String id;
  final List<String> binTypes; // ['general', 'recycling']
  final DateTime date;
  final String timeSlot; // '08:00 AM - 12:00 PM'
  final String location;
  final String? instructions;
  final String status; // 'pending', 'scheduled', 'completed', 'cancelled'

  const PickupRequestEntity({
    required this.id,
    required this.binTypes,
    required this.date,
    required this.timeSlot,
    required this.location,
    this.instructions,
    required this.status,
  });
}

class ServiceRecordEntity {
  final String id;
  final String title; // 'General Waste Collection', 'Monthly Subscription Payment'
  final String type; // 'collection', 'payment', 'support'
  final DateTime date;
  final String status; // 'completed', 'failed', 'pending'
  final double? weightKg;
  final double? co2OffsetKg;
  final Map<String, double>? compositionPercentages; // {'Plastics': 45.0, 'Paper': 35.0, 'Glass': 20.0}
  final double amountPaid;
  final String? receiptNumber;

  const ServiceRecordEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.status,
    this.weightKg,
    this.co2OffsetKg,
    this.compositionPercentages,
    required this.amountPaid,
    this.receiptNumber,
  });
}

class SubscriptionEntity {
  final String currentPlan; // 'Weekly Plan', 'Bi-weekly Plan', 'Monthly Plan', 'Pay-As-You-Go'
  final double fee;
  final String status; // 'active', 'expired', 'paused'
  final String paymentMethod; // 'Credit/Debit Card', 'Mobile Money', 'Apple Pay'
  final double outstandingBalance;
  final DateTime? nextPickupDate;

  const SubscriptionEntity({
    required this.currentPlan,
    required this.fee,
    required this.status,
    required this.paymentMethod,
    required this.outstandingBalance,
    this.nextPickupDate,
  });
}
