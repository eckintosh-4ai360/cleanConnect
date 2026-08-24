import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'paystack_checkout_screen.dart';

/// Sentinel URL Paystack redirects to once checkout finishes. Nothing is served
/// from it — the WebView intercepts the navigation. Must stay in sync with
/// PAYMENT_CALLBACK_URL in
/// supabase/functions/initialize-paystack-transaction/index.ts.
const String kPaystackCallbackUrl = 'https://cleanconnect.app/payment-complete';

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

/// Drives the full Paystack payment flow:
///
///   1. `initialize-paystack-transaction` creates the transaction server-side
///      (using the live secret key and the cleanConnect subaccount) and returns
///      an `authorization_url` + `reference`.
///   2. [PaystackCheckoutScreen] renders that hosted checkout page.
///   3. `verify-paystack-transaction` confirms the charge against Paystack's
///      own record before it is ever treated as paid.
///
/// Checkout is rendered as Paystack's hosted page rather than through the
/// native `paystack_flutter_sdk`, which is an abandoned alpha (two releases,
/// last pinned to Compose BOM 2023.01.00) that crashes on modern Compose and
/// has no web implementation.
class PaystackService {
  PaystackService._();
  static final PaystackService instance = PaystackService._();

  /// Starts a payment and returns only once it has been verified server-side.
  ///
  /// [email]             Customer's email address (required by Paystack).
  /// [amountInSmallest]  Amount in the smallest currency unit (pesewas for GHS,
  ///                     kobo for NGN). e.g. GHS 50.00 → 5000.
  /// [currency]          ISO 4217 currency code. Defaults to 'GHS'.
  /// [metadata]          Optional key-value pairs stored on the transaction.
  Future<PaymentResult> initiatePayment({
    required BuildContext context,
    required String email,
    required int amountInSmallest,
    String currency = 'GHS',
    Map<String, dynamic>? metadata,
  }) async {
    final String authorizationUrl;
    final String reference;

    // ── 1. Create the transaction server-side ───────────────────────────────
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

    // ── 2. Show Paystack's hosted checkout ──────────────────────────────────
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

    // A dismissed sheet may still have been charged (the customer could close
    // it during the redirect), so verify instead of assuming a cancellation.
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

    // ── 3. Confirm the charge with Paystack before trusting it ──────────────
    return _verifyTransaction(
      reference: reference,
      expectedAmount: amountInSmallest,
      expectedCurrency: currency,
    );
  }

  /// Confirms a transaction reference against Paystack's own record via the
  /// verify-paystack-transaction Edge Function. Only a confirmed, successful
  /// charge for the expected amount and currency counts as a real payment.
  ///
  /// [quiet] suppresses the "contact support" copy for the speculative check
  /// after a dismissed sheet, where a failure just means "not paid".
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
