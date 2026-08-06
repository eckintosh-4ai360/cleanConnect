import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/services/paystack_service.dart';

class SubscriptionScreen extends HookConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(customerSubscriptionProvider);
    final binsState = ref.watch(customerBinsProvider);
    final pricingPlansState = ref.watch(customerPricingPlansProvider);

    final selectedPlan = useState('Weekly Plan');
    final selectedFee = useState(15.0);
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
            _PlanData(title: 'Bi-weekly Plan', price: (10.0 * multiplier).roundToDouble(), description: 'Eco-conscious & flexible'),
            _PlanData(title: 'Monthly Plan', price: (6.0 * multiplier).roundToDouble(), description: 'Low volume waste collection'),
            _PlanData(title: 'Pay-As-You-Go', price: (3.0 * multiplier).roundToDouble(), description: 'Pay only when you request collection', isPayg: true),
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
        _PlanData(title: 'Bi-weekly Plan', price: 10.0, description: 'Eco-conscious & flexible'),
        _PlanData(title: 'Monthly Plan', price: 6.0, description: 'Low volume waste collection'),
        _PlanData(title: 'Pay-As-You-Go', price: 3.0, description: 'Pay only when you request collection', isPayg: true),
      ],
      loading: () => [
        _PlanData(title: 'Weekly Plan', price: 15.0, description: 'Most popular for busy households'),
        _PlanData(title: 'Bi-weekly Plan', price: 10.0, description: 'Eco-conscious & flexible'),
        _PlanData(title: 'Monthly Plan', price: 6.0, description: 'Low volume waste collection'),
        _PlanData(title: 'Pay-As-You-Go', price: 3.0, description: 'Pay only when you request collection', isPayg: true),
      ],
    );

    Future<void> handleSubscribe() async {
      if (isProcessing.value) return;

      final isPAYG = selectedPlan.value == 'Pay-As-You-Go';
      final fee = isPAYG ? 0.0 : selectedFee.value;

      // Pay-As-You-Go plans have no upfront fee — skip payment
      if (!isPAYG && fee > 0) {
        isProcessing.value = true;

        final currentUser = FirebaseAuth.instance.currentUser;
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

        // Amount in pesewas (GHS smallest unit): GHS 1 = 100 pesewas
        final amountInPesewas = (fee * 100).round();

        final result = await PaystackService.instance.initiatePayment(
          email: email,
          amountInSmallest: amountInPesewas,
          currency: 'GHS',
          metadata: {
            'plan': selectedPlan.value,
            'payment_method': selectedPaymentMethod.value,
            'type': 'subscription',
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
      }

      // Payment succeeded (or PAYG) — update the subscription in Firestore
      try {
        await ref.read(customerSubscriptionProvider.notifier).changePlan(
              newPlan: selectedPlan.value,
              fee: fee,
              paymentMethod: selectedPaymentMethod.value,
            );
        if (!context.mounted) return;
        _showSuccessDialog(context, selectedPlan.value);
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
                          selectedFee.value = plan.price;
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
                    : EcoButton(
                        text: 'Confirm & Subscribe via Paystack',
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
    final isPAYG = planName == 'Pay-As-You-Go';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(
              isPAYG ? 'Plan Activated!' : 'Payment Successful!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have successfully selected the $planName.'),
            const SizedBox(height: 8),
            Text(
              isPAYG
                  ? 'Paystack payment will be required whenever you request a pickup.'
                  : 'Your payment was processed securely via Paystack.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
