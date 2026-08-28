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

  /// Attempts made at initializing before giving up, including the first.
  ///
  /// Only a rejection that happened before the function ran is retried, so no
  /// charge can be duplicated by this — see [_isGatewayFailure].
  static const int _initializeAttempts = 2;

  /// Pause between initialize attempts.
  static const Duration _retryDelay = Duration(milliseconds: 600);

  /// Whether the request died in the infrastructure instead of being answered
  /// by our function.
  ///
  /// Our functions only ever reply in JSON, so a body that arrives as markup is
  /// the bare `400 Bad Request` page a proxy in front of the function serves
  /// when it rejects a request before routing it. The function never ran, which
  /// makes the attempt both safe to retry and pointless to report verbatim.
  bool _isGatewayFailure(FunctionException e) {
    final details = e.details;
    if (details is String && details.trimLeft().startsWith('<')) return true;
    return e.status >= 500;
  }

  /// A one-line form of a failure body, so an HTML error page does not spill
  /// several lines of markup into the log on every failed attempt.
  String _logBody(Object? details) {
    final text = details.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 200 ? text : '${text.substring(0, 200)}…';
  }

  /// Turns an edge-function failure into something that names the actual cause.
  ///
  /// This used to read `details['error']` and fall back to a bare "Payment
  /// server error" for anything else. But only our own functions answer in that
  /// shape: when a request is rejected by the Supabase gateway before it ever
  /// reaches the function, the body is `{code, message}`, and a platform or
  /// proxy failure is plain text. Both landed on the generic string, which hid
  /// the one piece of information needed to fix the problem. Every shape is now
  /// unwrapped, and the status code is always shown so a report is actionable.
  ///
  /// A proxy's HTML error page is the one body that is never unwrapped — it
  /// carries nothing a customer can act on, and reading it out would put a page
  /// of markup in the snack bar.
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
    } else if (details is String &&
        details.trim().isNotEmpty &&
        !details.trimLeft().startsWith('<')) {
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
    String? authorizationUrl;
    String? reference;
    PaymentResult? failure;

    // 1. Initialize transaction via Edge Function
    for (var attempt = 1; attempt <= _initializeAttempts; attempt++) {
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
        break;
      } on FunctionException catch (e) {
        debugPrint(
          '[PaystackService] Initialize failed '
          '(attempt $attempt/$_initializeAttempts): ${e.status} — '
          '${_logBody(e.details)}',
        );
        failure = PaymentResult(
          status: PaymentStatus.failed,
          errorMessage: _describeFunctionError(e),
        );
        // Anything the function itself answered is a verdict, not a blip.
        if (!_isGatewayFailure(e)) break;
        if (attempt < _initializeAttempts) await Future.delayed(_retryDelay);
      } catch (e) {
        debugPrint('[PaystackService] Initialize error: $e');
        failure = const PaymentResult(
          status: PaymentStatus.failed,
          errorMessage: 'Could not reach the payment service. Please try again.',
        );
        break;
      }
    }

    final checkoutUrl = authorizationUrl;
    final checkoutReference = reference;
    if (checkoutUrl == null || checkoutReference == null) {
      return failure ??
          const PaymentResult(
            status: PaymentStatus.failed,
            errorMessage: 'Could not start payment. Please try again.',
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
          authorizationUrl: checkoutUrl,
          callbackUrl: kPaystackCallbackUrl,
        ),
      ),
    );

    if (outcome == CheckoutOutcome.loadFailed) {
      return PaymentResult(
        status: PaymentStatus.failed,
        reference: checkoutReference,
        errorMessage: 'The payment page could not be loaded. Please try again.',
      );
    }

    // Verify even on dismiss in case payment went through before user closed sheet
    if (outcome != CheckoutOutcome.completed) {
      final verified = await _verifyTransaction(
        reference: checkoutReference,
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
      reference: checkoutReference,
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
        '${_describeFunctionError(e)} | raw: ${_logBody(e.details)}',
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
