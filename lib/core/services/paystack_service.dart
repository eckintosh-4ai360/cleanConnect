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
      final details = e.details;
      final message = details is Map ? details['error']?.toString() : null;
      debugPrint('[PaystackService] Initialize failed: ${e.status} — $message');
      return PaymentResult(
        status: PaymentStatus.failed,
        errorMessage: message ?? 'Payment server error. Please try again.',
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
      final details = e.details;
      final message = details is Map ? details['error']?.toString() : null;
      debugPrint('[PaystackService] Verify failed: ${e.status} — $message');
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
