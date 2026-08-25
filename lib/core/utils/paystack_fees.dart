/// Paystack's processing fee, and the gross-up that makes the customer cover it.
///
/// Paystack deducts its fee from whatever amount is charged, so charging the
/// list price leaves the company short. These helpers invert Paystack's own
/// formula: they work out the larger amount to charge such that, once the fee
/// is taken out, the settled amount is still the full list price.
///
/// Ghana local pricing (paystack.com/gh/pricing): 1.95%, no flat fee, no cap.
/// The flat fee, waiver and cap are kept here as constants so the maths still
/// holds if Paystack changes the pricing or the app adds another currency.
class PaystackFees {
  const PaystackFees._();

  /// Percentage taken off every local transaction — 1.95%.
  static const double percentage = 0.0195;

  /// Flat fee added on top of the percentage, in the smallest unit (pesewas).
  static const int flatFee = 0;

  /// Transactions below this amount have the flat fee waived.
  static const int flatFeeWaiverBelow = 0;

  /// Ceiling on the total fee, or null when the fee is uncapped.
  static const int? feeCap = null;

  /// Human-readable label for the fee line in the UI.
  static const String label = 'Paystack fee (1.95%)';

  /// GHS 1 = 100 pesewas.
  static int toSmallestUnit(double amount) => (amount * 100).round();

  /// The fee Paystack takes out of a transaction of [grossAmount] pesewas.
  ///
  /// Rounded up so the company is never left a pesewa short of the list price.
  static int feeOn(int grossAmount) {
    if (grossAmount <= 0) return 0;
    var fee = (grossAmount * percentage).ceil();
    if (grossAmount >= flatFeeWaiverBelow) fee += flatFee;
    const cap = feeCap;
    if (cap != null && fee > cap) fee = cap;
    return fee;
  }

  /// Splits a list price of [netAmount] pesewas into what the customer is
  /// charged and what Paystack keeps, so the company still settles [netAmount].
  static PaystackCharge chargeFor(int netAmount) {
    if (netAmount <= 0) return const PaystackCharge(net: 0, fee: 0, total: 0);

    // Solve total - fee(total) = net for total, then correct for the rounding,
    // the flat-fee waiver and the cap, which the closed form can't see.
    var total = ((netAmount + flatFee) / (1 - percentage)).ceil();
    const cap = feeCap;
    if (cap != null && total - netAmount > cap) total = netAmount + cap;
    while (total - feeOn(total) < netAmount) {
      total++;
    }
    while (total > netAmount && (total - 1) - feeOn(total - 1) >= netAmount) {
      total--;
    }

    return PaystackCharge(
      net: netAmount,
      fee: total - netAmount,
      total: total,
    );
  }

  /// [chargeFor] taking the list price as a currency amount (e.g. GHS 12.50).
  static PaystackCharge chargeForAmount(double netAmount) =>
      chargeFor(toSmallestUnit(netAmount));
}

/// A list price split into the customer's total and Paystack's cut.
class PaystackCharge {
  const PaystackCharge({
    required this.net,
    required this.fee,
    required this.total,
  });

  /// What the company settles, in the smallest unit.
  final int net;

  /// What Paystack deducts, in the smallest unit.
  final int fee;

  /// What the customer is charged, in the smallest unit.
  final int total;

  double get netAmount => net / 100;
  double get feeAmount => fee / 100;
  double get totalAmount => total / 100;

  bool get hasFee => fee > 0;
}
