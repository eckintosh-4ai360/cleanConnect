import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Replace with your real Paystack public key.
// Use pk_test_... for development; pk_live_... for production.
// ─────────────────────────────────────────────────────────────────────────────
const String _kPaystackPublicKey =
    'pk_test_96c65f269342874ea312d01fe4780598cec5de33';

/// The result returned after a Paystack payment attempt.
enum PaymentStatus { success, cancelled, failed }

class PaymentResult {
  final PaymentStatus status;
  final String? reference;
  final String? errorMessage;

  const PaymentResult({
    required this.status,
    this.reference,
    this.errorMessage,
  });

  bool get isSuccess => status == PaymentStatus.success;
}

/// Service that wraps the Paystack Flutter SDK and handles the full
/// payment initialization → launch → result flow.
class PaystackService {
  PaystackService._();
  static final PaystackService instance = PaystackService._();

  final Paystack _paystack = Paystack();
  bool _initialized = false;

  /// Call once at app startup (e.g. in main.dart after Firebase.initializeApp).
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final result = await _paystack.initialize(
        _kPaystackPublicKey,
        kDebugMode,
      );
      if (result) {
        _initialized = true;
        debugPrint('[PaystackService] SDK initialized successfully.');
      } else {
        debugPrint('[PaystackService] SDK initialization returned false.');
      }
    } catch (e) {
      debugPrint('[PaystackService] Initialization error: $e');
    }
  }

  /// Initiates a Paystack payment.
  ///
  /// [email]             Customer's email address (required by Paystack).
  /// [amountInSmallest]  Amount in the smallest currency unit (pesewas for GHS,
  ///                     kobo for NGN). e.g. GHS 50.00 → 5000.
  /// [currency]          ISO 4217 currency code. Defaults to 'GHS'.
  /// [metadata]          Optional key-value pairs stored on the transaction.
  Future<PaymentResult> initiatePayment({
    required String email,
    required int amountInSmallest,
    String currency = 'GHS',
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // ── 1. Get access_code from our Firebase Cloud Function ──────────────
      final callable = FirebaseFunctions.instance.httpsCallable(
        'initializePaystackTransaction',
      );

      final response = await callable.call<Map<String, dynamic>>({
        'email': email,
        'amount': amountInSmallest,
        'currency': currency,
        'metadata': metadata ?? {},
      });

      final data = response.data;
      final accessCode = data['access_code'] as String?;
      final reference = data['reference'] as String?;

      if (accessCode == null || accessCode.isEmpty) {
        return const PaymentResult(
          status: PaymentStatus.failed,
          errorMessage: 'Could not obtain payment access code from server.',
        );
      }

      // ── 2. Launch Paystack payment sheet ─────────────────────────────────
      await _paystack.launch(accessCode);

      // The SDK launches the Paystack web UI in a bottom sheet.
      // After the user completes or closes it, control returns here.
      // We optimistically treat return as success and verify via reference.
      return PaymentResult(status: PaymentStatus.success, reference: reference);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[PaystackService] Cloud Function error: ${e.code} — ${e.message}',
      );
      return PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: e.message ?? 'Payment server error. Please try again.',
      );
    } catch (e) {
      // User cancelled or SDK error
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') ||
          msg.contains('dismiss') ||
          msg.contains('close')) {
        return const PaymentResult(
          status: PaymentStatus.cancelled,
          errorMessage: 'Payment was cancelled.',
        );
      }
      debugPrint('[PaystackService] Payment error: $e');
      return const PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: 'Payment failed. Please try again.',
      );
    }
  }
}
