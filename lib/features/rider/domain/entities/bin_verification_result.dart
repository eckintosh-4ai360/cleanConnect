/// Result of scanning a bin's QR code against one specific pickup, returned
/// by the `verify_pickup_bin` RPC. Lets the Collection screen give the rider
/// instant feedback ("wrong bin!") before they bother entering a weight --
/// `complete_pickup` independently re-checks the same match server-side, so
/// this result is purely for UX speed, not the actual security boundary.
class BinVerificationResult {
  final bool verified;

  /// 'not_your_pickup' | 'bin_not_found' | 'wrong_customer', null when verified.
  final String? reason;
  final String? binId;
  final String? binType;
  final String? binSize;

  const BinVerificationResult({
    required this.verified,
    this.reason,
    this.binId,
    this.binType,
    this.binSize,
  });

  String get message {
    switch (reason) {
      case 'bin_not_found':
        return "This QR code doesn't match any registered bin.";
      case 'wrong_customer':
        return "This bin belongs to a different customer — scan the customer's own bin.";
      case 'not_your_pickup':
        return 'This pickup is not assigned to you.';
      default:
        return 'Could not verify this bin.';
    }
  }
}
