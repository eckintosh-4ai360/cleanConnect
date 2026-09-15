import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/customer_providers.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/payg_pricing.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/clean_connect_button.dart';
import '../../../../core/services/paystack_service.dart';
import '../../../../core/utils/paystack_fees.dart';

/// Display-only check for a plan whose price is charged per pickup. Whether a
/// pickup actually needs paying for is decided by SubscriptionEntity.isPayAsYouGo,
/// which the database derives -- this just tolerates both the seeded
/// 'Pay As You Go' and the older hyphenated spelling in UI copy.
bool _looksPayg(String planName) =>
    planName.toLowerCase().replaceAll('-', ' ').trim() == 'pay as you go';

class SubscriptionScreen extends HookConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(customerSubscriptionProvider);
    final binsState = ref.watch(customerBinsProvider);
    final pricingPlansState = ref.watch(customerPricingPlansProvider);
    final creditsState = ref.watch(customerPaygCreditsProvider);
    final requestsState = ref.watch(customerPickupRequestsProvider);

    final selectedPlan = useState('Weekly Plan');
    final selectedPaymentMethod = useState('Mobile Money');
    final isProcessing = useState(false);

    // Determine customer's bin size from registered bins or default to 240L
    final userBinSize = binsState.when(
      data: (bins) => bins.isNotEmpty ? bins.first.size : '240L',
      error: (_, _) => '240L',
      loading: () => '240L',
    );

    // Build dynamic plans list from Firestore pricingPlans collection
    final List<_PlanData> plans = pricingPlansState.when(
      data: (pricingPlans) {
        if (pricingPlans.isEmpty) {
          // Default fallback plans scaling with bin capacity if admin hasn't created plans yet
          final multiplier = userBinSize == '120L' ? 0.7 : (userBinSize == '360L' ? 1.4 : 1.0);
          return [
            _PlanData(title: 'Weekly Plan', price: (15.0 * multiplier).roundToDouble(), description: 'Most popular for busy households'),
            _PlanData(title: 'Bi-weekly Plan', price: (10.0 * multiplier).roundToDouble(), description: 'Clean-conscious & flexible'),
            _PlanData(title: 'Monthly Plan', price: (6.0 * multiplier).roundToDouble(), description: 'Low volume waste collection'),
            _PlanData(title: 'Pay As You Go', price: (3.0 * multiplier).roundToDouble(), description: 'Pay only when you request collection', isPayg: true),
          ];
        }
        return pricingPlans.map((plan) {
          final price = plan.getPriceForSize(userBinSize);
          return _PlanData(
            title: plan.name,
            price: price,
            description: plan.description.isNotEmpty ? plan.description : (plan.isPayg ? 'Pay per collection request' : 'Recurring collection plan'),
            isPayg: plan.isPayg,
          );
        }).toList();
      },
      error: (_, _) => [
        _PlanData(title: 'Weekly Plan', price: 15.0, description: 'Most popular for busy households'),
        _PlanData(title: 'Bi-weekly Plan', price: 10.0, description: 'Clean-conscious & flexible'),
        _PlanData(title: 'Monthly Plan', price: 6.0, description: 'Low volume waste collection'),
        _PlanData(title: 'Pay As You Go', price: 3.0, description: 'Pay only when you request collection', isPayg: true),
      ],
      loading: () => [
        _PlanData(title: 'Weekly Plan', price: 15.0, description: 'Most popular for busy households'),
        _PlanData(title: 'Bi-weekly Plan', price: 10.0, description: 'Clean-conscious & flexible'),
        _PlanData(title: 'Monthly Plan', price: 6.0, description: 'Low volume waste collection'),
        _PlanData(title: 'Pay As You Go', price: 3.0, description: 'Pay only when you request collection', isPayg: true),
      ],
    );

    // Details of the highlighted plan, plus what Paystack has to charge for it
    final matchingPlans = plans.where((p) => p.title == selectedPlan.value);
    final selectedPlanData = matchingPlans.isEmpty ? null : matchingPlans.first;
    final isPaygSelected = selectedPlanData?.isPayg ?? _looksPayg(selectedPlan.value);

    // Pay-as-you-go is paid one pickup at a time, before the pickup can be
    // requested. A pickup already paid for but not yet requested is used
    // first, so the customer is never charged twice for the same pickup.
    final availableCredits =
        creditsState.value ?? const <PaygPickupCreditEntity>[];
    final prepaidPickup = availableCredits.isEmpty ? null : availableCredits.first;
    final paygQuote = PaygQuote.forCustomer(
      plans: pricingPlansState.value ?? const [],
      binSize: userBinSize,
      delayBonusEligible: isDelayBonusEligible(
        requestsState.value ?? const [],
        subState.value,
      ),
      overduePayment: hasOverduePayment(subState.value),
    );

    final selectedAmount = isPaygSelected
        ? (prepaidPickup != null ? 0.0 : paygQuote.total)
        : (selectedPlanData?.price ?? 0.0);
    final selectedCharge = selectedAmount > 0
        ? PaystackFees.chargeForAmount(selectedAmount)
        : null;

    Future<void> handleSubscribe() async {
      if (isProcessing.value) return;

      final isPAYG = isPaygSelected;
      final amount = selectedAmount;
      String? paymentReference;

      // Nothing to charge only when a prepaid pickup is already waiting.
      if (amount > 0) {
        isProcessing.value = true;

        final currentUser = Supabase.instance.client.auth.currentUser;
        final email = currentUser?.email ?? '';

        if (email.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not retrieve your email. Please sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
          isProcessing.value = false;
          return;
        }

        // Charge the grossed-up amount so the fee survives Paystack's cut
        final charge = PaystackFees.chargeForAmount(amount);

        final result = await PaystackService.instance.initiatePayment(
          context: context,
          email: email,
          amountInSmallest: charge.total,
          currency: 'GHS',
          metadata: {
            'plan': selectedPlan.value,
            'payment_method': selectedPaymentMethod.value,
            // verify-paystack-transaction turns a payg_pickup_credit charge
            // into the one pickup it pays for.
            'type': isPAYG ? 'payg_pickup_credit' : 'subscription',
            if (isPAYG) ...{
              'original_total': paygQuote.originalTotal,
              'discount_percentage': paygQuote.discountPercentage,
              'surcharge_percentage': paygQuote.surchargePercentage,
            },
            'net_total': charge.netAmount,
            'paystack_fee': charge.feeAmount,
            'amount_charged': charge.totalAmount,
          },
        );

        isProcessing.value = false;

        if (!context.mounted) return;

        if (result.status == PaymentStatus.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        if (!result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Payment failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        paymentReference = result.reference;
      }

      // Payment succeeded (or a prepaid pickup already exists) — save the plan
      try {
        await ref.read(customerSubscriptionProvider.notifier).changePlan(
              newPlan: selectedPlan.value,
              fee: isPAYG ? 0.0 : amount,
              paymentMethod: selectedPaymentMethod.value,
              paymentReference: paymentReference,
            );
        if (!context.mounted) return;
        if (isPAYG) {
          _showPrepaidPickupDialog(
            context,
            charged: paymentReference != null,
            amount: amount > 0 ? amount : prepaidPickup?.amount,
          );
        } else {
          _showSuccessDialog(context, selectedPlan.value);
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: const Text('Choose Your Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: -1),
      body: SafeArea(
        child: subState.when(
          data: (currentSub) => SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Plan banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : const Color(0xFFFFF7EA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0A500).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR ACTIVE PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            currentSub.currentPlan,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (!currentSub.isPayAsYouGo && currentSub.paidUntil != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Paid until ${DateFormat('EEE d MMM yyyy').format(currentSub.paidUntil!.toLocal())} · pickups come automatically on your bin days',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ],
                          if (currentSub.isPayAsYouGo) ...[
                            const SizedBox(height: 2),
                            Text(
                              prepaidPickup != null
                                  ? '1 prepaid pickup ready to request'
                                  : 'No prepaid pickup — pay before requesting',
                              style: TextStyle(
                                fontSize: 12,
                                color: prepaidPickup != null ? Colors.green : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Choose a plan below', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bin size: $userBinSize',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Plans List
                Column(
                  children: plans.map((plan) {
                    final isSelected = selectedPlan.value == plan.title;
                    final formattedPrice = plan.price.truncateToDouble() == plan.price
                        ? plan.price.toInt().toString()
                        : plan.price.toStringAsFixed(2);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                          selectedPlan.value = plan.title;
                        },
                        title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(plan.description, style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan.isPayg
                                  ? 'GHS $formattedPrice/pickup'
                                  : 'GHS $formattedPrice/mo',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // Payment Options
                Row(
                  children: [
                    _PaymentTypeButton(
                      label: 'Card',
                      icon: Icons.credit_card_outlined,
                      isSelected: selectedPaymentMethod.value == 'Credit/Debit Card',
                      onTap: () => selectedPaymentMethod.value = 'Credit/Debit Card',
                    ),
                    const SizedBox(width: 12),
                    _PaymentTypeButton(
                      label: 'Mobile Money',
                      icon: Icons.phone_android_outlined,
                      isSelected: selectedPaymentMethod.value == 'Mobile Money',
                      onTap: () => selectedPaymentMethod.value = 'Mobile Money',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (isPaygSelected && prepaidPickup != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'You already paid GHS ${prepaidPickup.amount.toStringAsFixed(2)} for a pickup '
                      'you have not requested yet. Request it first — you can pay for '
                      'another one after that pickup.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // What Paystack will actually charge for the selected plan
                if (selectedCharge != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isPaygSelected ? 'Pickup fee (1 pickup)' : 'Plan fee',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                      Text(
                        'GHS ${(isPaygSelected ? paygQuote.originalTotal : selectedCharge.netAmount).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (isPaygSelected && paygQuote.discountPercentage > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delay bonus (-${paygQuote.discountPercentage.toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                        ),
                        Text(
                          '- GHS ${paygQuote.discountAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                  if (isPaygSelected && paygQuote.surchargePercentage > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Late payment surcharge (+${paygQuote.surchargePercentage.toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                        ),
                        Text(
                          '+ GHS ${paygQuote.surchargeAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          PaystackFees.label,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                      Text(
                        '+ GHS ${selectedCharge.feeAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total to pay',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'GHS ${selectedCharge.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Paystack badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by Paystack',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Subscribe Button
                isProcessing.value
                    ? const Center(child: CircularProgressIndicator())
                    : CleanConnectButton(
                        text: isPaygSelected
                            ? (selectedCharge == null
                                ? 'Use My Prepaid Pickup'
                                : 'Pay GHS ${selectedCharge.totalAmount.toStringAsFixed(2)} for 1 Pickup')
                            : (selectedCharge == null
                                ? 'Confirm & Subscribe via Paystack'
                                : 'Pay GHS ${selectedCharge.totalAmount.toStringAsFixed(2)} & Subscribe'),
                        onPressed: handleSubscribe,
                      ),
              ],
            ),
          ),
          error: (_, _) => const Center(child: Text('Error loading subscription state.')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment Successful!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have successfully selected the $planName.'),
            const SizedBox(height: 8),
            const Text(
              'Your pickups will now be scheduled automatically every week on the day and time '
              'you chose for your bins — no need to request each one.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

/// Pay-as-you-go confirmation: the payment is for one pickup, so point the
/// customer straight at requesting it.
void _showPrepaidPickupDialog(
  BuildContext context, {
  required bool charged,
  double? amount,
}) {
  final amountText = amount == null ? '' : ' (GHS ${amount.toStringAsFixed(2)})';
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              charged ? 'Payment Successful!' : 'Prepaid Pickup Ready',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You have paid for one pickup$amountText. Request it now.'),
          const SizedBox(height: 8),
          const Text(
            'Pay As You Go covers one pickup per payment. After this pickup, '
            'come back here and pay again before your next request.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go('/dashboard');
          },
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go('/customer/request-pickup');
          },
          child: const Text('Request Pickup'),
        ),
      ],
    ),
  );
}

class _PlanData {
  final String title;
  final double price;
  final String description;
  final bool isPayg;

  _PlanData({
    required this.title,
    required this.price,
    required this.description,
    this.isPayg = false,
  });
}

class _PaymentTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.primary : Colors.grey),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
