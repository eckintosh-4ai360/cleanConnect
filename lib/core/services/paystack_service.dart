import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'paystack_checkout_screen.dart';

// Callback URL intercepted by WebView when checkout finishes
const String kPaystackCallbackUrl = 'https://cleanconnect.app/payment-complete';

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

/// Service handling Paystack transaction initialization, checkout WebView, and verification
class PaystackService {
  PaystackService._();
  static final PaystackService instance = PaystackService._();

  /// Turns an edge-function failure into something that names the actual cause.
  ///
  /// This used to read `details['error']` and fall back to a bare "Payment
  /// server error" for anything else. But only our own functions answer in that
  /// shape: when a request is rejected by the Supabase gateway before it ever
  /// reaches the function, the body is `{code, message}`, and a platform or
  /// proxy failure is plain text. Both landed on the generic string, which hid
  /// the one piece of information needed to fix the problem. Every shape is now
  /// unwrapped, and the status code is always shown so a report is actionable.
  String _describeFunctionError(FunctionException e) {
    final details = e.details;

    String? extracted;
    if (details is Map) {
      // 'error' is our own functions; 'message'/'msg' is the Supabase gateway.
      for (final key in const ['error', 'message', 'msg']) {
        final value = details[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          extracted = value.toString().trim();
          break;
        }
      }
    } else if (details is String && details.trim().isNotEmpty) {
      extracted = details.trim();
    }

    if (extracted == null || extracted.isEmpty) {
      return 'Payment service error (HTTP ${e.status}). Please try again.';
    }
    return '$extracted (HTTP ${e.status})';
  }

  // Initiates transaction, shows checkout sheet, and verifies payment status
  Future<PaymentResult> initiatePayment({
    required BuildContext context,
    required String email,
    required int amountInSmallest,
    String currency = 'GHS',
    Map<String, dynamic>? metadata,
  }) async {
    final String authorizationUrl;
    final String reference;

    // 1. Initialize transaction via Edge Function
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

      final data = response.data as Map<String, dynamic>?;
      final url = data?['authorization_url'] as String?;
      final ref = data?['reference'] as String?;

      if (url == null || url.isEmpty || ref == null || ref.isEmpty) {
        debugPrint('[PaystackService] Initialize returned no checkout URL.');
        return const PaymentResult(
          status: PaymentStatus.failed,
          errorMessage: 'Could not start payment. Please try again.',
        );
      }
      authorizationUrl = url;
      reference = ref;
    } on FunctionException catch (e) {
      final message = _describeFunctionError(e);
      debugPrint('[PaystackService] Initialize failed: ${e.status} — ${e.details}');
      return PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: message,
      );
    } catch (e) {
      debugPrint('[PaystackService] Initialize error: $e');
      return const PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: 'Could not reach the payment service. Please try again.',
      );
    }

    // 2. Open Paystack hosted checkout in a WebView
    if (!context.mounted) {
      return const PaymentResult(
        status: PaymentStatus.cancelled,
        errorMessage: 'Payment was cancelled.',
      );
    }

    final outcome = await Navigator.of(context).push<CheckoutOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaystackCheckoutScreen(
          authorizationUrl: authorizationUrl,
          callbackUrl: kPaystackCallbackUrl,
        ),
      ),
    );

    if (outcome == CheckoutOutcome.loadFailed) {
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage: 'The payment page could not be loaded. Please try again.',
      );
    }

    // Verify even on dismiss in case payment went through before user closed sheet
    if (outcome != CheckoutOutcome.completed) {
      final verified = await _verifyTransaction(
        reference: reference,
        expectedAmount: amountInSmallest,
        expectedCurrency: currency,
        quiet: true,
      );
      if (verified.isSuccess) return verified;
      return const PaymentResult(
        status: PaymentStatus.cancelled,
        errorMessage: 'Payment was cancelled.',
      );
    }

    // 3. Verify transaction server-side
    return _verifyTransaction(
      reference: reference,
      expectedAmount: amountInSmallest,
      expectedCurrency: currency,
    );
  }

  // Verifies transaction via Edge Function against Paystack API
  Future<PaymentResult> _verifyTransaction({
    required String reference,
    required int expectedAmount,
    required String expectedCurrency,
    bool quiet = false,
  }) async {
    String failureMessage() => quiet
        ? 'Payment was not completed.'
        : 'Payment could not be confirmed. If you were charged, contact support '
              'with reference $reference.';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-paystack-transaction',
        body: {
          'reference': reference,
          'expected_amount': expectedAmount,
          'expected_currency': expectedCurrency,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data?['verified'] == true) {
        return PaymentResult(
          status: PaymentStatus.success,
          reference: reference,
        );
      }
      if (!quiet) {
        debugPrint('[PaystackService] Verification rejected: $data');
      }
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage: failureMessage(),
      );
    } on FunctionException catch (e) {
      debugPrint(
        '[PaystackService] Verify failed: ${e.status} — '
        '${_describeFunctionError(e)} | raw: ${e.details}',
      );
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage: failureMessage(),
      );
    } catch (e) {
      debugPrint('[PaystackService] Verification error: $e');
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: reference,
        errorMessage: failureMessage(),
      );
    }
  }
}
