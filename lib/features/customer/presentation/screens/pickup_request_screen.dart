import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/customer_providers.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/payg_pricing.dart';
import '../../../../core/shared/widgets/clean_connect_button.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/paystack_fees.dart';
import 'location_picker_screen.dart';

class PickupRequestScreen extends HookConsumerWidget {
  const PickupRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binsState = ref.watch(customerBinsProvider);
    final subState = ref.watch(customerSubscriptionProvider);

    // Pay-as-you-go pickups are paid for up front on the plan screen; each
    // payment is one credit that this request uses up.
    final paygCreditsState = ref.watch(customerPaygCreditsProvider);
    final prepaidPickup = (paygCreditsState.value ?? const []).isEmpty
        ? null
        : paygCreditsState.value!.first;

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
    // Pickup location is always a real GPS fix -- either the device's current
    // position or a pin the customer dropped on the map -- never typed text,
    // since riders navigate off these coordinates.
    final selectedLocation = useState<LatLng?>(null);
    final selectedLocationLabel = useState<String?>(null);
    final isLocating = useState(false);

    final isSubmitting = useState(false);
    final isInitialized = useState(false);

    // Subscription state. Whether this pickup has to be paid for comes from
    // the database's derived flag, never from the plan's display name -- the
    // seeded plan is 'Pay As You Go' while this screen used to compare against
    // 'Pay-As-You-Go', so the charge was skipped for everybody. Absent state
    // means charge.
    final currentPlan = subState.value?.currentPlan ?? 'Pay As You Go';
    final isPayAsYouGo = subState.value?.isPayAsYouGo ?? true;

    // List of date options (next 7 days). Pay-as-you-go pickups are paid for
    // immediately at booking time, so those customers can also book same-day.
    final dateOptions = useMemoized(() {
      final upcoming = List.generate(
        7,
        (index) => DateTime.now().add(Duration(days: index + 1)),
      );
      return isPayAsYouGo ? [DateTime.now(), ...upcoming] : upcoming;
    }, [isPayAsYouGo]);

    // Auto-populate dynamic defaults from customer's profile, bin registration, and subscription
    useEffect(() {
      if (!isInitialized.value && binsState.hasValue) {
        final bins = binsState.value ?? [];

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

          // 2. Pre-select location from the registered bin's GPS fix -- it is
          // already real coordinates, not typed text, so it is safe to default
          // to. The customer can still override it below.
          final binLocation = GeoUtils.tryParseLatLng(primaryBin.gpsLocation);
          if (binLocation != null) {
            selectedLocation.value = binLocation;
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

        isInitialized.value = true;
      }
      return null;
    }, [binsState.hasValue, subState.hasValue]);

    Future<void> useCurrentLocation() async {
      isLocating.value = true;
      final access = await LocationService.instance.ensurePermission();

      if (!context.mounted) {
        isLocating.value = false;
        return;
      }

      switch (access) {
        case LocationAccess.granted:
          final position = await LocationService.instance.currentPosition();
          if (position != null) {
            selectedLocation.value = LatLng(position.latitude, position.longitude);
            selectedLocationLabel.value = await DirectionsService.instance
                .reverseGeocode(selectedLocation.value!);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not get your current location. Try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        case LocationAccess.serviceDisabled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Turn on location services to use this.'),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: LocationService.instance.openLocationSettings,
              ),
            ),
          );
        case LocationAccess.deniedForever:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is blocked for CleanConnect.'),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: LocationService.instance.openAppSettings,
              ),
            ),
          );
        case LocationAccess.denied:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission was not granted.')),
          );
      }

      isLocating.value = false;
    }

    Future<void> chooseOnMap() async {
      // Try a real GPS fix before falling back to the Tarkwa placeholder, so
      // the picker opens centered on the customer's actual position instead
      // of always looking like it's ignoring GPS.
      if (selectedLocation.value == null) {
        await useCurrentLocation();
        if (!context.mounted) return;
      }

      final result = await Navigator.of(context).push<PickedLocation>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialPosition: selectedLocation.value ?? MapConfig.fallbackCenter,
          ),
        ),
      );
      if (result != null) {
        selectedLocation.value = result.position;
        selectedLocationLabel.value = result.label;
      }
    }

    final requestsState = ref.watch(customerPickupRequestsProvider);

    final isBonusEligible =
        isDelayBonusEligible(requestsState.value ?? const [], subState.value);
    final overduePayment = hasOverduePayment(subState.value);

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

    // What the customer would pay on the plan screen if they have no prepaid
    // pickup yet -- shown so they know the price before leaving this form.
    final paygQuote = PaygQuote.forCustomer(
      plans: pricingPlansState.value ?? const [],
      binSize: userBinSize,
      delayBonusEligible: isBonusEligible,
      overduePayment: overduePayment,
    );
    final paygCharge = PaystackFees.chargeForAmount(paygQuote.total);
    final needsPayment = isPayAsYouGo && prepaidPickup == null;

    void goPayForPickup() => context.push('/customer/subscription');

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

      if (selectedLocation.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set a pickup location using your current location or the map.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final credit = prepaidPickup;
      if (isPayAsYouGo && credit == null) {
        goPayForPickup();
        return;
      }

      isSubmitting.value = true;

      try {
        String paymentMethodToSave = 'Covered by $currentPlan';
        double finalAmountPaid = 0.0;
        double originalAmount = 0.0;
        double discountPercentage = 0.0;
        double surchargePercentage = 0.0;
        String? paymentReference;

        // The server takes these from the credit it consumes; they are sent
        // so the request is consistent with what the customer saw.
        if (isPayAsYouGo && credit != null) {
          paymentMethodToSave = credit.paymentMethod ?? 'Paystack';
          finalAmountPaid = credit.amount;
          originalAmount = credit.amount;
          discountPercentage = credit.discountAppliedPercentage;
          surchargePercentage = credit.surchargeAppliedPercentage;
          paymentReference = credit.paymentReference;
        }

        final destination = selectedLocation.value!;
        final finalLocation = selectedLocationLabel.value?.trim().isNotEmpty == true
            ? selectedLocationLabel.value!.trim()
            : GeoUtils.formatCoordinates(destination.latitude, destination.longitude);

        // ── Step 2: Save pickup request
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
              originalAmount: originalAmount,
              discountAppliedPercentage: discountPercentage,
              surchargeAppliedPercentage: surchargePercentage,
              locationLat: destination.latitude,
              locationLng: destination.longitude,
              paymentReference: paymentReference,
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
                    final isToday =
                        DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
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
                              isToday
                                  ? 'TODAY'
                                  : DateFormat('E').format(date).toUpperCase(),
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

              // Pickup location is set by GPS fix or map pin only -- never by
              // typing an address -- so riders always navigate to a real point.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selectedLocation.value == null
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: selectedLocation.value == null
                          ? Colors.orange
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: selectedLocation.value == null
                          ? const Text(
                              'No pickup location set yet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            )
                          : Text(
                              selectedLocationLabel.value ??
                                  '${selectedLocation.value!.latitude.toStringAsFixed(6)}, '
                                      '${selectedLocation.value!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLocating.value ? null : useCurrentLocation,
                      icon: isLocating.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Use Current Location'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chooseOnMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Choose on Map'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Picking up for someone else? Use "Choose on Map" to drop a pin at their address.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                  if (isBonusEligible && needsPayment)
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
              if (isBonusEligible && needsPayment)
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
                              'Riders failed to pick up after 3 days grace period. 10% off will be applied when you pay for your next pickup!',
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
              if (overduePayment && needsPayment)
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
                              'An outstanding balance was not settled within 3 days of your last completed pickup. A 10% surcharge will be added when you pay for your next pickup.',
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

              if (isPayAsYouGo && prepaidPickup != null)
                _PrepaidPickupCard(credit: prepaidPickup, isDark: isDark)
              else if (isPayAsYouGo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade900
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_clock_outlined, color: Colors.amber.shade800),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Payment required first',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Text(
                            'GHS ${paygCharge.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You are on Pay As You Go. Pay for this pickup on the plan '
                        'screen, then come back to request it. Each payment covers '
                        'one pickup.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (paygCharge.hasFee) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Includes ${PaystackFees.label}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
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
              CleanConnectButton(
                text: needsPayment
                    ? 'Pay for a Pickup First'
                    : isPayAsYouGo
                        ? 'Confirm Prepaid Pickup'
                        : 'Confirm Pickup',
                onPressed: needsPayment ? goPayForPickup : handleConfirmPickup,
                isLoading: isSubmitting.value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pay-as-you-go payment this request will use.
class _PrepaidPickupCard extends StatelessWidget {
  final PaygPickupCreditEntity credit;
  final bool isDark;

  const _PrepaidPickupCard({required this.credit, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prepaid pickup — GHS ${credit.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${credit.paymentMethod ?? 'Paystack'} · paid ${DateFormat('d MMM, h:mm a').format(credit.paidAt.toLocal())}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (credit.discountAppliedPercentage > 0)
                  Text(
                    '${credit.discountAppliedPercentage.toStringAsFixed(0)}% delay bonus applied',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'This payment covers this one pickup. Your next pickup needs a new payment.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
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
