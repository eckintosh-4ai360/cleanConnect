import 'entities/customer_entities.dart';

/// Price of one pay-as-you-go pickup for [binSize].
///
/// Uses the admin's pay-as-you-go plan when one is priced, otherwise the
/// weekly plan plus 30%, the rate the admin panel advertises for PAYG.
double paygPickupFee(List<PricingPlanEntity> plans, String binSize) {
  for (final plan in plans) {
    if (plan.isPayg) {
      final price = plan.getPriceForSize(binSize);
      if (price > 0) return price;
    }
  }
  for (final plan in plans) {
    if (plan.frequency.toLowerCase() == 'weekly') {
      final weekly = plan.getPriceForSize(binSize);
      if (weekly > 0) return weekly * 1.30;
    }
  }
  return 65.0; // GHS 50.00 weekly + 30%
}

/// A pickup that was not collected within 3 days of its date earns the
/// customer 10% off their next one.
bool isDelayBonusEligible(
  List<PickupRequestEntity> requests,
  SubscriptionEntity? subscription,
) =>
    requests.any((r) => r.isOverdueBeyondGracePeriod) ||
    (subscription?.delayBonusAvailable ?? false);

/// Money still owed more than 3 days after the last completed pickup adds a
/// 10% surcharge to the next one.
bool hasOverduePayment(SubscriptionEntity? subscription) {
  if (subscription == null || subscription.outstandingBalance <= 0) return false;
  final completedAt = subscription.lastPickupCompletedAt;
  if (completedAt == null) return false;
  return DateTime.now().difference(completedAt).inDays > 3;
}

/// What one pay-as-you-go pickup costs right now, before Paystack's fee.
class PaygQuote {
  final double originalTotal;
  final double discountPercentage;
  final double surchargePercentage;

  const PaygQuote({
    required this.originalTotal,
    this.discountPercentage = 0.0,
    this.surchargePercentage = 0.0,
  });

  factory PaygQuote.forCustomer({
    required List<PricingPlanEntity> plans,
    required String binSize,
    required bool delayBonusEligible,
    required bool overduePayment,
  }) =>
      PaygQuote(
        originalTotal: paygPickupFee(plans, binSize),
        discountPercentage: delayBonusEligible ? 10.0 : 0.0,
        surchargePercentage: overduePayment ? 10.0 : 0.0,
      );

  double get discountAmount => originalTotal * discountPercentage / 100;
  double get surchargeAmount => originalTotal * surchargePercentage / 100;
  double get total => originalTotal - discountAmount + surchargeAmount;
}
