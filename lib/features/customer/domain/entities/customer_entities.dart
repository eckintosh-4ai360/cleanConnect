class BinEntity {
  final String id;
  final String serialNumber;
  final String type; // 'general', 'recycling', 'organic'
  final String size; // '120L', '240L', '360L'
  final double fillLevelPercentage; // 0.0 to 1.0 (e.g. 0.45 = 45%)
  final String? scheduleFrequency; // 'Weekly', 'Bi-weekly', 'Monthly'
  final List<String>? pickupDays; // ['Monday', 'Thursday']
  final String? gpsLocation;
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
    this.gpsLocation,
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
    String? gpsLocation,
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
      gpsLocation: gpsLocation ?? this.gpsLocation,
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
  final String status; // 'pending', 'scheduled', 'completed', 'cancelled', 'overdue_delayed'
  final double amountPaid;
  final double originalAmount;
  final double discountAppliedPercentage; // e.g. 10.0 for 10% discount
  final double surchargeAppliedPercentage; // e.g. 10.0 for 10% late-payment surcharge

  const PickupRequestEntity({
    required this.id,
    required this.binTypes,
    required this.date,
    required this.timeSlot,
    required this.location,
    this.instructions,
    required this.status,
    this.amountPaid = 0.0,
    this.originalAmount = 0.0,
    this.discountAppliedPercentage = 0.0,
    this.surchargeAppliedPercentage = 0.0,
  });

  /// True if pickup was not completed on scheduled date
  bool get isDelayed {
    if (status == 'completed' || status == 'cancelled') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDay = DateTime(date.year, date.month, date.day);
    return today.isAfter(scheduledDay);
  }

  /// Calculates number of days delayed past the scheduled date
  int get daysDelayed {
    if (!isDelayed) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDay = DateTime(date.year, date.month, date.day);
    return today.difference(scheduledDay).inDays;
  }

  /// Remaining days in the 3-day grace period (max 3, min 0)
  int get remainingGraceDays {
    if (!isDelayed) return 3;
    final daysPast = daysDelayed;
    final remaining = 3 - daysPast;
    return remaining < 0 ? 0 : remaining;
  }

  /// True if rider failed to pick up after the 3rd day of grace period
  bool get isOverdueBeyondGracePeriod {
    return isDelayed && daysDelayed > 3;
  }
}

class ServiceRecordEntity {
  final String id;
  // 'General Waste Collection', 'Monthly Subscription Payment'
  final String title;
  final String type; // 'collection', 'payment', 'support'
  final DateTime date;
  final String status; // 'completed', 'failed', 'pending'
  final double? weightKg;
  final double? co2OffsetKg;
  // {'Plastics': 45.0, 'Paper': 35.0, 'Glass': 20.0}
  final Map<String, double>? compositionPercentages;
  final double amountPaid;
  final String? receiptNumber;
  final String? paymentMethod;

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
    this.paymentMethod,
  });
}

class SubscriptionEntity {
  // 'Weekly Plan', 'Bi-weekly Plan', 'Monthly Plan', 'Pay-As-You-Go'
  final String currentPlan;
  final double fee;
  final String status; // 'active', 'expired', 'paused'
  // 'Credit/Debit Card', 'Mobile Money', 'Apple Pay'
  final String paymentMethod;
  final double outstandingBalance;
  final DateTime? nextPickupDate;
  final String? nextPickupTimeSlot;
  final List<String>? nextPickupBinTypes;
  final bool delayBonusAvailable; // true if rider delayed past 3-day grace period
  final DateTime? lastPickupCompletedAt;

  const SubscriptionEntity({
    required this.currentPlan,
    required this.fee,
    required this.status,
    required this.paymentMethod,
    required this.outstandingBalance,
    this.nextPickupDate,
    this.nextPickupTimeSlot,
    this.nextPickupBinTypes,
    this.delayBonusAvailable = false,
    this.lastPickupCompletedAt,
  });
}

class PricingPlanEntity {
  final String id;
  final String name;
  final String frequency;
  final String description;
  final bool isPayg;
  final Map<String, double> prices; // e.g. {'120L': 10.0, '240L': 15.0, '360L': 20.0}

  const PricingPlanEntity({
    required this.id,
    required this.name,
    required this.frequency,
    required this.description,
    required this.isPayg,
    required this.prices,
  });

  double getPriceForSize(String size) {
    if (prices.containsKey(size)) {
      return prices[size]!;
    }
    // Fallback to 240L if available, or first available price, or 0.0
    if (prices.containsKey('240L')) {
      return prices['240L']!;
    }
    return prices.values.isNotEmpty ? prices.values.first : 0.0;
  }
}
