import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/customer_providers.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/services/paystack_service.dart';

class PickupRequestScreen extends HookConsumerWidget {
  const PickupRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binsState = ref.watch(customerBinsProvider);
    final subState = ref.watch(customerSubscriptionProvider);

    // State of requested pickup details (default to recycling)
    final selectedBins = useState<List<String>>(['recycling']);
    final selectedDate = useState<DateTime>(
      DateTime.now().add(const Duration(days: 1)),
    );
    // Dynamic time slot initialization based on time of day
    final defaultTimeSlot = DateTime.now().hour < 12
        ? '08:00 AM - 12:00 PM'
        : '12:00 PM - 04:00 PM';
    final selectedTimeSlot = useState(defaultTimeSlot);

    final driverNotesController = useTextEditingController();
    final addressSelection = useState('');
    final isCustomAddress = useState(false);
    final customAddressController = useTextEditingController();

    // Dynamic payment method initialized from customer subscription profile
    final selectedPaymentMethod = useState(
      subState.value?.paymentMethod ?? 'Mobile Money',
    );

    final isSubmitting = useState(false);
    final isInitialized = useState(false);

    // Subscription state
    final currentPlan = subState.value?.currentPlan ?? 'Pay-As-You-Go';
    final isPayAsYouGo = currentPlan == 'Pay-As-You-Go';

    // List of date options (next 7 days)
    final dateOptions = useMemoized(() {
      return List.generate(
        7,
        (index) => DateTime.now().add(Duration(days: index + 1)),
      );
    });

    // Auto-populate dynamic defaults from customer's profile, bin registration, and subscription
    useEffect(() {
      if (subState.hasValue && subState.value?.paymentMethod != null) {
        if (selectedPaymentMethod.value.isEmpty || selectedPaymentMethod.value == 'Mobile Money') {
          selectedPaymentMethod.value = subState.value!.paymentMethod;
        }
      }

      if (!isInitialized.value && binsState.hasValue) {
        final bins = binsState.value ?? [];
        final currentUser = Supabase.instance.client.auth.currentUser;

        if (bins.isNotEmpty) {
          final primaryBin = bins.first;

          // 1. Pre-select the bin type actually chosen at registration
          // (mirrors the primary bin used for location/day below — a
          // customer registers one type per bin, so default to that one
          // instead of unioning every bin they've ever registered).
          final primaryType = primaryBin.type.toLowerCase();
          if (primaryType == 'recycling' || primaryType == 'organic') {
            selectedBins.value = [primaryType];
          }

          // 2. Pre-select location from registered bin GPS location
          if (primaryBin.gpsLocation != null &&
              primaryBin.gpsLocation!.trim().isNotEmpty) {
            addressSelection.value = primaryBin.gpsLocation!;
          }

          // 3. Pre-select date matching customer's preferred pickup day
          if (primaryBin.pickupDays != null &&
              primaryBin.pickupDays!.isNotEmpty) {
            final prefDays = primaryBin.pickupDays!
                .map((d) => d.toLowerCase())
                .toList();
            for (final date in dateOptions) {
              final dayName = DateFormat('EEEE').format(date).toLowerCase();
              if (prefDays.contains(dayName)) {
                selectedDate.value = date;
                break;
              }
            }
          }
        }

        // Fallback address from user profile if bin location is empty
        if (addressSelection.value.isEmpty) {
          if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
            final userName = currentUser.userMetadata?['full_name'] as String? ?? 'Customer';
            addressSelection.value = '$userName Address';
          } else {
            addressSelection.value = 'Primary Service Location';
          }
        }

        isInitialized.value = true;
      }
      return null;
    }, [binsState.hasValue, subState.hasValue]);

    final requestsState = ref.watch(customerPickupRequestsProvider);

    // Auto-detect if customer has any pickup request delayed past 3 days grace period
    final hasOverdueDelayBonus = useMemoized(() {
      final requests = requestsState.value ?? [];
      return requests.any((r) => r.isOverdueBeyondGracePeriod);
    }, [requestsState.value]);

    final isBonusEligible =
        hasOverdueDelayBonus || (subState.value?.delayBonusAvailable ?? false);

    final timeSlots = [
      '08:00 AM - 12:00 PM', // Morning
      '12:00 PM - 04:00 PM', // Afternoon
    ];

    final userBinSize = binsState.when(
      data: (bins) => bins.isNotEmpty ? bins.first.size : '240L',
      error: (_, _) => '240L',
      loading: () => '240L',
    );

    final pricingPlansState = ref.watch(customerPricingPlansProvider);

    // Dynamic Pay-As-You-Go per-bin fee (Weekly Price + 30% of Weekly Price)
    final pickupFeePerBin = useMemoized(() {
      final plans = pricingPlansState.value ?? [];

      // 1. Check if admin configured a PAYG plan directly in Firestore
      for (final plan in plans) {
        if (plan.isPayg) {
          final p = plan.getPriceForSize(userBinSize);
          if (p > 0) return p;
        }
      }

      // 2. Otherwise calculate as Weekly Price + 30% of Weekly Price (130%)
      for (final plan in plans) {
        if (plan.frequency.toLowerCase() == 'weekly') {
          final wPrice = plan.getPriceForSize(userBinSize);
          if (wPrice > 0) return (wPrice * 1.30);
        }
      }

      return 65.0; // fallback (GHS 50.00 weekly + 30% = GHS 65.00)
    }, [pricingPlansState.value, userBinSize]);

    // Customer still owes money more than 3 days after their last completed
    // pickup: their next request carries a 10% surcharge for the company.
    final hasOverduePayment = useMemoized(() {
      final sub = subState.value;
      if (sub == null || sub.outstandingBalance <= 0) return false;
      final completedAt = sub.lastPickupCompletedAt;
      if (completedAt == null) return false;
      return DateTime.now().difference(completedAt).inDays > 3;
    }, [subState.value]);

    final originalTotal = selectedBins.value.length * pickupFeePerBin;
    final discountPercentage = isBonusEligible ? 10.0 : 0.0;
    final discountAmount = isBonusEligible ? (originalTotal * 0.10) : 0.0;
    final surchargePercentage = hasOverduePayment ? 10.0 : 0.0;
    final surchargeAmount = hasOverduePayment ? (originalTotal * 0.10) : 0.0;
    final pickupTotal = originalTotal - discountAmount + surchargeAmount;

    Future<void> handleConfirmPickup() async {
      if (selectedBins.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select at least one bin type to schedule collection.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      isSubmitting.value = true;

      try {
        String paymentMethodToSave = 'Covered by $currentPlan';
        double finalAmountPaid = 0.0;

        // ── Step 1: Process Paystack payment if user is on Pay-As-You-Go ────
        if (isPayAsYouGo) {
          final currentUser = Supabase.instance.client.auth.currentUser;
          final email = currentUser?.email ?? '';

          if (email.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not retrieve your account email. Please sign in again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            isSubmitting.value = false;
            return;
          }

          final amountInPesewas = (pickupTotal * 100).round();

          final paymentResult = await PaystackService.instance.initiatePayment(
            email: email,
            amountInSmallest: amountInPesewas,
            currency: 'GHS',
            metadata: {
              'type': 'pickup_request_pay_as_you_go',
              'bin_types': selectedBins.value.join(', '),
              'pickup_date': DateFormat(
                'yyyy-MM-dd',
              ).format(selectedDate.value),
              'time_slot': selectedTimeSlot.value,
              'discount_percentage': discountPercentage,
              'surcharge_percentage': surchargePercentage,
              'original_total': originalTotal,
            },
          );

          if (!context.mounted) return;

          if (paymentResult.status == PaymentStatus.cancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment cancelled. Your pickup was not scheduled.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            isSubmitting.value = false;
            return;
          }

          if (!paymentResult.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  paymentResult.errorMessage ??
                      'Payment failed. Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            isSubmitting.value = false;
            return;
          }

          paymentMethodToSave = 'Paystack (${selectedPaymentMethod.value})';
          finalAmountPaid = pickupTotal;
        }

        final finalLocation = isCustomAddress.value &&
                customAddressController.text.trim().isNotEmpty
            ? customAddressController.text.trim()
            : (addressSelection.value.trim().isNotEmpty
                ? addressSelection.value.trim()
                : 'Primary Service Location');

        // ── Step 2: Save pickup request to Firestore
        await ref
            .read(customerPickupRequestsProvider.notifier)
            .requestPickup(
              binTypes: selectedBins.value,
              date: selectedDate.value,
              timeSlot: selectedTimeSlot.value,
              location: finalLocation,
              amountPaid: finalAmountPaid,
              paymentMethod: paymentMethodToSave,
              instructions: driverNotesController.text,
              originalAmount: originalTotal,
              discountAppliedPercentage: discountPercentage,
              surchargeAppliedPercentage: surchargePercentage,
            );

        if (!context.mounted) return;
        context.go('/customer/pickup-confirmed');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        isSubmitting.value = false;
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Request Pickup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Bin Types',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Bins selection check lists (Recycling & Organic)
              _BinCheckboxTile(
                label: 'Recycling',
                icon: Icons.recycling_outlined,
                color: Colors.blue,
                isSelected: selectedBins.value.contains('recycling'),
                onChanged: (val) {
                  final list = List<String>.from(selectedBins.value);
                  if (val == true) {
                    list.add('recycling');
                  } else {
                    list.remove('recycling');
                  }
                  selectedBins.value = list;
                },
              ),
              _BinCheckboxTile(
                label: 'Organic Waste',
                icon: Icons.eco_outlined,
                color: Colors.green,
                isSelected: selectedBins.value.contains('organic'),
                onChanged: (val) {
                  final list = List<String>.from(selectedBins.value);
                  if (val == true) {
                    list.add('organic');
                  } else {
                    list.remove('organic');
                  }
                  selectedBins.value = list;
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Pickup Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Horizontal Date slider list
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dateOptions.length,
                  itemBuilder: (context, index) {
                    final date = dateOptions[index];
                    final isSelected =
                        DateFormat('yyyy-MM-dd').format(selectedDate.value) ==
                        DateFormat('yyyy-MM-dd').format(date);
                    return GestureDetector(
                      onTap: () => selectedDate.value = date,
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Select Pickup Time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Grid of timeslots
              Row(
                children: timeSlots.map((slot) {
                  final isSelected = selectedTimeSlot.value == slot;
                  final isMorning = slot.contains('08:00 AM');
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => selectedTimeSlot.value = slot,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isMorning
                                  ? Icons.wb_sunny_outlined
                                  : Icons.wb_twilight_outlined,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isMorning ? 'Morning' : 'Afternoon',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${slot.split(' ').first} - ${slot.split(' - ').last.split(' ').first}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.8,
                                      )
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              const Text(
                'Pickup Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Dynamic Location Dropdown & Custom Address Field
              Builder(
                builder: (context) {
                  final bins = binsState.value ?? [];
                  final requests = requestsState.value ?? [];
                  final currentUser = Supabase.instance.client.auth.currentUser;
                  final currentUserName = currentUser?.userMetadata?['full_name'] as String?;

                  final locationOptions = <String>{};

                  // 1. Registered bin locations
                  for (final bin in bins) {
                    if (bin.gpsLocation != null && bin.gpsLocation!.trim().isNotEmpty) {
                      locationOptions.add(bin.gpsLocation!.trim());
                    }
                  }

                  // 2. Previous requests' locations
                  for (final req in requests) {
                    if (req.location.trim().isNotEmpty) {
                      locationOptions.add(req.location.trim());
                    }
                  }

                  // 3. Current selected address
                  if (addressSelection.value.trim().isNotEmpty) {
                    locationOptions.add(addressSelection.value.trim());
                  }

                  // 4. Default user location tag
                  if (locationOptions.isEmpty) {
                    final defaultLoc = currentUserName != null
                        ? '$currentUserName\'s Service Location'
                        : 'Primary Service Location';
                    locationOptions.add(defaultLoc);
                  }

                  final optionsList = locationOptions.toList();
                  optionsList.add('+ Enter Custom Address');

                  final currentSelection = isCustomAddress.value
                      ? '+ Enter Custom Address'
                      : (optionsList.contains(addressSelection.value)
                          ? addressSelection.value
                          : optionsList.first);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: currentSelection,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: optionsList.map((loc) {
                          return DropdownMenuItem<String>(
                            value: loc,
                            child: Text(
                              loc,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: loc.startsWith('+')
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: loc.startsWith('+')
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == '+ Enter Custom Address') {
                            isCustomAddress.value = true;
                          } else if (val != null) {
                            isCustomAddress.value = false;
                            addressSelection.value = val;
                          }
                        },
                      ),
                      if (isCustomAddress.value) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Enter Custom Pickup Address',
                            hintText: 'e.g. House 42, Palm Avenue, East Legon',
                            prefixIcon: Icon(Icons.edit_location_alt_outlined),
                          ),
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              addressSelection.value = val.trim();
                            }
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPayAsYouGo ? 'Payment (Pay-As-You-Go)' : 'Payment Status',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isBonusEligible)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 14,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '10% Delay Bonus On',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 🎁 Rider Delay Compensation Banner (if 10% bonus active)
              if (isBonusEligible)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.green.shade900, Colors.teal.shade900]
                          : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.green.shade700
                          : Colors.green.shade400,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    '10% DELAY BONUS APPLIED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                      letterSpacing: 0.8,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '10% OFF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Riders failed to pick up after 3 days grace period. 10% discount applied to your next pickup!',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : const Color(0xFF1B5E20),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ⚠️ Late Payment Surcharge Banner (if 10% surcharge active)
              if (hasOverduePayment)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.red.shade900.withValues(alpha: 0.3)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.red.shade700 : Colors.red.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '10% LATE PAYMENT SURCHARGE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.red,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'An outstanding balance was not settled within 3 days of your last completed pickup. A 10% surcharge has been added to this request.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : const Color(0xFFB71C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (isPayAsYouGo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade900
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBonusEligible
                          ? Colors.green.shade400
                          : (hasOverduePayment
                              ? Colors.red.shade300
                              : Colors.amber.shade200),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pickup Charge',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              if (isBonusEligible || hasOverduePayment) ...[
                                Text(
                                  'GHS ${originalTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.red,
                                    decorationThickness: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'GHS ${pickupTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: isBonusEligible
                                      ? Colors.green.shade700
                                      : (hasOverduePayment
                                          ? Colors.red.shade700
                                          : null),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedBins.value.length} bin${selectedBins.value.length == 1 ? '' : 's'} x GHS ${pickupFeePerBin.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (isBonusEligible) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delay Bonus (-10%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              '- GHS ${discountAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasOverduePayment) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Late Payment Surcharge (+10%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              '+ GHS ${surchargeAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isBonusEligible && !hasOverduePayment) ...[
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Paystack payment required',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC78200),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _PaymentMethodTile(
                              label: 'Mobile Money',
                              icon: Icons.phone_android_outlined,
                              isSelected:
                                  selectedPaymentMethod.value == 'Mobile Money',
                              onTap: () =>
                                  selectedPaymentMethod.value = 'Mobile Money',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PaymentMethodTile(
                              label: 'Card',
                              icon: Icons.credit_card_outlined,
                              isSelected: selectedPaymentMethod.value == 'Card',
                              onTap: () => selectedPaymentMethod.value = 'Card',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade900
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Covered by $currentPlan',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'No additional per-pickup charge required.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              const Text(
                'Instructions for the driver (optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // Instructions field
              TextField(
                controller: driverNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Leave bins near the fence, beware of dog...',
                ),
              ),

              const SizedBox(height: 32),
              EcoButton(
                text: isPayAsYouGo
                    ? 'Pay GHS ${pickupTotal.toStringAsFixed(2)} & Confirm Pickup'
                    : 'Confirm Pickup',
                onPressed: handleConfirmPickup,
                isLoading: isSubmitting.value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BinCheckboxTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _BinCheckboxTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        activeColor: const Color(0xFFF0A500),
        secondary: Icon(icon, color: color),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
