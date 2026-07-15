import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/customer_providers.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class PickupRequestScreen extends HookConsumerWidget {
  const PickupRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // State of requested pickup details
    final selectedBins = useState<List<String>>(['general']);
    final selectedDate = useState<DateTime>(DateTime.now().add(const Duration(days: 1)));
    final selectedTimeSlot = useState('08:00 AM - 12:00 PM');
    final driverNotesController = useTextEditingController();
    final addressSelection = useState('Home: 123 Green St, Eco City');

    final isSubmitting = useState(false);

    // List of date options (next 7 days)
    final dateOptions = useMemoized(() {
      return List.generate(7, (index) => DateTime.now().add(Duration(days: index + 1)));
    });

    final timeSlots = [
      '08:00 AM - 12:00 PM', // Morning
      '12:00 PM - 04:00 PM', // Afternoon
    ];

    Future<void> handleConfirmPickup() async {
      if (selectedBins.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one bin type to schedule collection.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      isSubmitting.value = true;
      try {
        await ref.read(customerPickupRequestsProvider.notifier).requestPickup(
              binTypes: selectedBins.value,
              date: selectedDate.value,
              timeSlot: selectedTimeSlot.value,
              location: addressSelection.value,
              instructions: driverNotesController.text,
            );
        if (!context.mounted) return;
        // Direct route to the confirmation landing screen
        context.go('/customer/pickup-confirmed');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request pickup: $e'), backgroundColor: Colors.red),
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
        title: const Text('Request Pickup', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Bin Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // Bins selection check lists
              _BinCheckboxTile(
                label: 'General Waste',
                icon: Icons.delete_outline,
                color: Colors.grey,
                isSelected: selectedBins.value.contains('general'),
                onChanged: (val) {
                  final list = List<String>.from(selectedBins.value);
                  if (val == true) {
                    list.add('general');
                  } else {
                    list.remove('general');
                  }
                  selectedBins.value = list;
                },
              ),
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

              const Text('Select Pickup Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // Horizontal Date slider list
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dateOptions.length,
                  itemBuilder: (context, index) {
                    final date = dateOptions[index];
                    final isSelected = DateFormat('yyyy-MM-dd').format(selectedDate.value) ==
                        DateFormat('yyyy-MM-dd').format(date);
                    return GestureDetector(
                      onTap: () => selectedDate.value = date,
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(date).toUpperCase(), // e.g. MON
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('d').format(date), // e.g. 15
                              style: TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.w900,
                                 color: isSelected ? Colors.white : theme.colorScheme.onBackground,
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
              const Text('Select Pickup Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isMorning ? Icons.wb_sunny_outlined : Icons.wb_twilight_outlined,
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isMorning ? 'Morning' : 'Afternoon',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slot.split(' ').first + ' - ' + slot.split(' - ').last.split(' ').first,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? theme.colorScheme.primary.withOpacity(0.8) : Colors.grey,
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
              const Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // Location Dropdown
              DropdownButtonFormField<String>(
                value: addressSelection.value,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined)),
                items: const [
                  DropdownMenuItem(value: 'Home: 123 Green St, Eco City', child: Text('Home: 123 Green St, Eco City')),
                  DropdownMenuItem(value: 'Office: 456 Corporate Way, Eco City', child: Text('Office: 456 Corporate Way')),
                ],
                onChanged: (val) {
                  if (val != null) addressSelection.value = val;
                },
              ),

              const SizedBox(height: 24),
              const Text('Instructions for the driver (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                text: 'Confirm Pickup',
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
