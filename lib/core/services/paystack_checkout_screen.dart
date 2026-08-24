import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// How the hosted Paystack checkout page was closed.
///
/// [completed] only means Paystack redirected to the callback URL — it is not
/// proof of payment. PaystackService still verifies the reference server-side
/// before treating the charge as real.
enum CheckoutOutcome { completed, cancelled, loadFailed }

/// Renders Paystack's hosted checkout (the `authorization_url` returned by the
/// initialize-paystack-transaction Edge Function) and pops with a
/// [CheckoutOutcome] once the page redirects to the callback URL or the user
/// backs out.
class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.callbackUrl,
  });

  final String authorizationUrl;
  final String callbackUrl;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Guards against popping twice — onPageStarted and onNavigationRequest can
  /// both see the callback URL for a single redirect.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isCallback(request.url)) {
              _finish(CheckoutOutcome.completed);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (_isCallback(url)) _finish(CheckoutOutcome.completed);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Sub-resources (fonts, analytics beacons) fail routinely on the
            // checkout page; only a failure of the main document means the
            // customer is looking at a broken screen.
            if (error.isForMainFrame ?? false) {
              _finish(CheckoutOutcome.loadFailed);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  bool _isCallback(String url) => url.startsWith(widget.callbackUrl);

  void _finish(CheckoutOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  Future<void> _confirmCancel() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'Your payment has not been completed. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep paying'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (shouldLeave == true) _finish(CheckoutOutcome.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmCancel,
          ),
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
