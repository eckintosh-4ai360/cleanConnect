import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class SubscriptionScreen extends HookConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(customerSubscriptionProvider);

    // Selected plan and payment details local state
    final selectedPlan = useState('Weekly Plan');
    final selectedFee = useState(15.0);
    final selectedPaymentMethod = useState('Credit/Debit Card');

    // Controllers for payment details bottom sheet
    final cardNumberController = useTextEditingController();
    final expiryController = useTextEditingController();
    final cvvController = useTextEditingController();

    final plans = [
      _PlanData(title: 'Weekly Plan', price: 15.0, description: 'Most popular for busy households'),
      _PlanData(title: 'Bi-weekly Plan', price: 10.0, description: 'Eco-conscious & flexible'),
      _PlanData(title: 'Monthly Plan', price: 6.0, description: 'Low volume waste collection'),
      _PlanData(title: 'Pay-As-You-Go', price: 3.0, description: 'Pay only when you request collection'),
    ];

    void handleSubscribe() {
      if (selectedPaymentMethod.value == 'Credit/Debit Card' && cardNumberController.text.isEmpty) {
        // Open card modal first
        _showCardDetailsSheet(
          context,
          cardNumberController,
          expiryController,
          cvvController,
          () {
            ref.read(customerSubscriptionProvider.notifier).changePlan(
                  newPlan: selectedPlan.value,
                  fee: selectedPlan.value == 'Pay-As-You-Go' ? 0.0 : selectedFee.value,
                  paymentMethod: selectedPaymentMethod.value,
                );
            Navigator.pop(context);
            _showSuccessDialog(context, selectedPlan.value);
          },
        );
      } else {
        ref.read(customerSubscriptionProvider.notifier).changePlan(
              newPlan: selectedPlan.value,
              fee: selectedPlan.value == 'Pay-As-You-Go' ? 0.0 : selectedFee.value,
              paymentMethod: selectedPaymentMethod.value,
            );
        _showSuccessDialog(context, selectedPlan.value);
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
                // Current Plan info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : const Color(0xFFFFF7EA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0A500).withOpacity(0.3)),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
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

                const Text('Choose a plan below', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // Plans List
                Column(
                  children: plans.map((plan) {
                    final isSelected = selectedPlan.value == plan.title;
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
                              plan.title == 'Pay-As-You-Go'
                                  ? '\$${plan.price.toInt()}/pickup'
                                  : '\$${plan.price.toInt()}/mo',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onBackground,
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
                const SizedBox(height: 32),

                // Subscribe Action Button
                EcoButton(
                  text: 'Confirm & Subscribe',
                  onPressed: handleSubscribe,
                ),
              ],
            ),
          ),
          error: (_, __) => const Center(child: Text('Error loading subscription state.')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showCardDetailsSheet(
    BuildContext context,
    TextEditingController cardController,
    TextEditingController expiryController,
    TextEditingController cvvController,
    VoidCallback onSubmit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Card Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cardController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: 'XXXX XXXX XXXX XXXX',
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: 'XXX',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              EcoButton(
                text: 'Pay Securely',
                onPressed: onSubmit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
            Text('Success!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('You have successfully subscribed to the $planName.'),
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

  _PlanData({
    required this.title,
    required this.price,
    required this.description,
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
