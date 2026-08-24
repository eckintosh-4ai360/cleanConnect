import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';

const String _kPaystackPublicKey =
    'pk_live_87977e3c5dfa23a80d45cb51424c9df83c9a8e03';

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
      final errorStr = e.toString();
      if (errorStr.contains('MissingPluginException') ||
          errorStr.contains('No implementation found')) {
        debugPrint(
          '[PaystackService] Native plugin channel unavailable on this platform/session. Test mode will be used if needed.',
        );
      } else {
        debugPrint('[PaystackService] Initialization notice: $e');
      }
    }
  }

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
      // ── 1. Attempt Edge Function access_code generation ────────────────
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'initialize-paystack-transaction',
          body: {
            'email': email,
            'amount': amountInSmallest,
            'currency': currency,
            'metadata': metadata ?? {},
          },
        );

        final data = response.data as Map<String, dynamic>;
        final accessCode = data['access_code'] as String?;
        final reference = data['reference'] as String?;

        if (accessCode != null && accessCode.isNotEmpty && reference != null) {
          // Launch Paystack SDK UI
          try {
            await _paystack.launch(accessCode);
          } catch (launchErr) {
            final msg = launchErr.toString();
            if (msg.contains('MissingPluginException') ||
                msg.contains('No implementation found')) {
              if (kDebugMode) {
                // Plugin missing on current platform/session — fallback to test success
                debugPrint(
                  '[PaystackService] Native SDK UI unavailable. Completing in test mode.',
                );
                return PaymentResult(
                  status: PaymentStatus.success,
                  reference: 'PST-DEV-${DateTime.now().millisecondsSinceEpoch}',
                );
              }
              return const PaymentResult(
                status: PaymentStatus.failed,
                errorMessage:
                    'Payment could not be started on this device. Please try again.',
              );
            }
            if (msg.toLowerCase().contains('cancel') ||
                msg.toLowerCase().contains('dismiss') ||
                msg.toLowerCase().contains('close')) {
              return const PaymentResult(
                status: PaymentStatus.cancelled,
                errorMessage: 'Payment was cancelled.',
              );
            }
            rethrow;
          }
          return _verifyTransaction(
            reference: reference,
            expectedAmount: amountInSmallest,
            expectedCurrency: currency,
          );
        }
      } on FunctionException catch (e) {
        final errorBody = e.details;
        final errorMessage = errorBody is Map
            ? errorBody['error']?.toString()
            : null;
        debugPrint(
          '[PaystackService] Edge Function notice: ${e.status} — $errorMessage',
        );
        // If in debug/test environment and function is not yet deployed or secret not set, fallback to test payment
        if (kDebugMode) {
          debugPrint(
            '[PaystackService] Debug mode: Simulated Paystack payment approval.',
          );
          return PaymentResult(
            status: PaymentStatus.success,
            reference: 'PST-DEV-${DateTime.now().millisecondsSinceEpoch}',
          );
        }
        return PaymentResult(
          status: PaymentStatus.failed,
          errorMessage:
              errorMessage ?? 'Payment server error. Please try again.',
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('MissingPluginException') ||
          msg.contains('No implementation found')) {
        if (kDebugMode) {
          debugPrint(
            '[PaystackService] Native plugin unavailable. Completing in test mode.',
          );
          return PaymentResult(
            status: PaymentStatus.success,
            reference: 'PST-DEV-${DateTime.now().millisecondsSinceEpoch}',
          );
        }
      }
      if (msg.toLowerCase().contains('cancel') ||
          msg.toLowerCase().contains('dismiss') ||
          msg.toLowerCase().contains('close')) {
        return const PaymentResult(
          status: PaymentStatus.cancelled,
          errorMessage: 'Payment was cancelled.',
        );
      }
      debugPrint('[PaystackService] Payment error: $e');
      if (kDebugMode) {
        return PaymentResult(
          status: PaymentStatus.success,
          reference: 'PST-DEV-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      return const PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: 'Payment failed. Please try again.',
      );
    }

    return const PaymentResult(
      status: PaymentStatus.failed,
      errorMessage: 'Payment could not be started. Please try again.',
    );
  }

  /// Confirms a transaction reference with Paystack's own record via the
  /// verify-paystack-transaction Edge Function. Only a confirmed, successful
  /// charge for the expected amount/currency is treated as a real payment.
  Future<PaymentResult> _verifyTransaction({
    required String reference,
    required int expectedAmount,
    required String expectedCurrency,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-paystack-transaction',
        body: {
          'reference': reference,
          'expected_amount': expectedAmount,
          'expected_currency': expectedCurrency,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['verified'] == true) {
        return PaymentResult(
          status: PaymentStatus.success,
          reference: reference,
        );
      }
      debugPrint('[PaystackService] Verification rejected: $data');
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage:
            'Payment could not be confirmed. If you were charged, contact support with reference $reference.',
      );
    } on FunctionException catch (e) {
      final errorBody = e.details;
      final errorMessage = errorBody is Map
          ? errorBody['error']?.toString()
          : null;
      debugPrint(
        '[PaystackService] Verify Edge Function notice: ${e.status} — $errorMessage',
      );
      if (kDebugMode) {
        debugPrint(
          '[PaystackService] Debug mode: skipping verification, assuming success.',
        );
        return PaymentResult(
          status: PaymentStatus.success,
          reference: reference,
        );
      }
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage:
            'Could not verify your payment. If you were charged, contact support with reference $reference.',
      );
    } catch (e) {
      debugPrint('[PaystackService] Verification error: $e');
      if (kDebugMode) {
        return PaymentResult(
          status: PaymentStatus.success,
          reference: reference,
        );
      }
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage:
            'Could not verify your payment. If you were charged, contact support with reference $reference.',
      );
    }
  }
}
