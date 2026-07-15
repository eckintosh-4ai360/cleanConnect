import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/customer_providers.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';

class BinRegisterScreen extends HookConsumerWidget {
  const BinRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = useState(0);

    // Form inputs state
    final selectedType = useState('general'); // 'general', 'recycling', 'organic'
    final selectedSize = useState('240L'); // '120L', '240L', '360L'
    final serialController = useTextEditingController();
    final gpsLocation = useState('');
    final photoPath = useState<String?>(null);

    // Step 2 inputs state
    final selectedFrequency = useState('Weekly'); // 'Weekly', 'Bi-weekly', 'Monthly'
    final preferredDays = useState<List<String>>(['Monday']);
    final startDate = useState<DateTime>(DateTime.now().add(const Duration(days: 1)));

    final formKey1 = useMemoized(() => GlobalKey<FormState>());

    // Geolocator GPS detection
    Future<void> detectLocation() async {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is denied.')),
            );
            return;
          }
        }
        gpsLocation.value = 'Fetching GPS coordinates...';
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        gpsLocation.value = '${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° W';
      } catch (e) {
        gpsLocation.value = '5.6037° N, 0.1870° W (Fallback)';
      }
    }

    // Capture Image
    Future<void> captureImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        photoPath.value = pickedFile.path;
      }
    }

    void handleNextStep() {
      if (currentStep.value == 0) {
        if (formKey1.currentState?.validate() ?? false) {
          if (gpsLocation.value.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please detect your GPS location.'), backgroundColor: Colors.orange),
            );
            return;
          }
          currentStep.value = 1;
        }
      } else if (currentStep.value == 1) {
        currentStep.value = 2;
      }
    }

    void handleBackStep() {
      if (currentStep.value > 0) {
        currentStep.value--;
      } else {
        context.pop();
      }
    }

    Future<void> handleConfirm() async {
      ref.read(customerBinsProvider.notifier).registerNewBin(
            type: selectedType.value,
            size: selectedSize.value,
            serialNumber: serialController.text.trim(),
            frequency: selectedFrequency.value,
            pickupDays: preferredDays.value,
            gpsLocation: gpsLocation.value,
            photoPath: photoPath.value,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bin Registered Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Register Bin', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: handleBackStep,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Steps Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = currentStep.value >= index;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: [
                  // Step 1: Specs Page
                  Form(
                    key: formKey1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Bin Type',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _TypeButton(
                              label: 'General',
                              icon: Icons.delete_outline,
                              isSelected: selectedType.value == 'general',
                              onTap: () => selectedType.value = 'general',
                            ),
                            const SizedBox(width: 12),
                            _TypeButton(
                              label: 'Recycling',
                              icon: Icons.recycling_outlined,
                              isSelected: selectedType.value == 'recycling',
                              onTap: () => selectedType.value = 'recycling',
                            ),
                            const SizedBox(width: 12),
                            _TypeButton(
                              label: 'Organic',
                              icon: Icons.eco_outlined,
                              isSelected: selectedType.value == 'organic',
                              onTap: () => selectedType.value = 'organic',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Bin Specifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        // Dropdown for capacity
                        DropdownButtonFormField<String>(
                          value: selectedSize.value,
                          decoration: const InputDecoration(labelText: 'Bin Capacity'),
                          items: const [
                            DropdownMenuItem(value: '120L', child: Text('120L Small')),
                            DropdownMenuItem(value: '240L', child: Text('240L Large')),
                            DropdownMenuItem(value: '360L', child: Text('360L Extra Large')),
                          ],
                          onChanged: (val) {
                            if (val != null) selectedSize.value = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        EcoTextField(
                          labelText: 'Serial Number',
                          hintText: 'Enter bin serial (e.g. BSD-8824-U1)',
                          controller: serialController,
                          prefixIcon: const Icon(Icons.pin_outlined),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter serial number';
                            }
                            return null;
                          },
                        ),
                        // Location Assignment
                        EcoTextField(
                          labelText: 'Location Assignment',
                          hintText: 'Detecting location...',
                          controller: TextEditingController(text: gpsLocation.value),
                          readOnly: true,
                          onTap: detectLocation,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location, color: Color(0xFFF0A500)),
                            onPressed: detectLocation,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Photo Verification card
                        const Text(
                          'Photo Verification',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: captureImage,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : const Color(0xFFFFF7EA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.shade200, style: BorderStyle.solid),
                            ),
                            child: photoPath.value != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(File(photoPath.value!), fit: BoxFit.cover),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, color: Color(0xFFF0A500), size: 30),
                                      SizedBox(height: 6),
                                      Text(
                                        'Take Photo of Bin',
                                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        EcoButton(
                          text: 'Register Bin',
                          onPressed: handleNextStep,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Step 2: Schedule settings
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Collection Schedule',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Configure how often your waste bin needs collection.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Select Collection Frequency',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      _FrequencyTile(
                        title: 'Weekly',
                        subtitle: 'Most popular for households',
                        isSelected: selectedFrequency.value == 'Weekly',
                        onTap: () {
                          selectedFrequency.value = 'Weekly';
                          preferredDays.value = ['Monday'];
                        },
                      ),
                      _FrequencyTile(
                        title: 'Bi-weekly',
                        subtitle: 'Eco-conscious choice',
                        isSelected: selectedFrequency.value == 'Bi-weekly',
                        onTap: () {
                          selectedFrequency.value = 'Bi-weekly';
                          preferredDays.value = ['Wednesday'];
                        },
                      ),
                      _FrequencyTile(
                        title: 'Monthly',
                        subtitle: 'Low volume waste',
                        isSelected: selectedFrequency.value == 'Monthly',
                        onTap: () {
                          selectedFrequency.value = 'Monthly';
                          preferredDays.value = ['Friday'];
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Preferred Pickup Day',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select the day that works best for your schedule.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                          final dayFullName = day == 'M'
                              ? 'Monday'
                              : (day == 'T' && day == 'T'
                                  ? 'Tuesday'
                                  : (day == 'W'
                                      ? 'Wednesday'
                                      : (day == 'T'
                                          ? 'Thursday'
                                          : (day == 'F' ? 'Friday' : (day == 'S' ? 'Saturday' : 'Sunday')))));
                          final isSelected = preferredDays.value.contains(dayFullName);
                          return GestureDetector(
                            onTap: () {
                              preferredDays.value = [dayFullName];
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : theme.colorScheme.onBackground,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      EcoButton(
                        text: 'Next',
                        onPressed: handleNextStep,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),

                  // Step 3: Review Page
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review & Confirm',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Verify your details before completing registration.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      // Summary Details card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? theme.cardTheme.color : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              icon: Icons.delete,
                              label: 'Bin Details',
                              value: '${selectedType.value.toUpperCase()} (${selectedSize.value})',
                            ),
                            const Divider(height: 24),
                            _SummaryRow(
                              icon: Icons.pin_outlined,
                              label: 'Serial Number',
                              value: serialController.text,
                            ),
                            const Divider(height: 24),
                            _SummaryRow(
                              icon: Icons.location_on_outlined,
                              label: 'Location',
                              value: gpsLocation.value,
                            ),
                            const Divider(height: 24),
                            _SummaryRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Collection Schedule',
                              value: '${selectedFrequency.value} (${preferredDays.value.first})',
                            ),
                            if (photoPath.value != null) ...[
                              const Divider(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.image_outlined, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Verification Photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(photoPath.value!),
                                            height: 100,
                                            width: 150,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      EcoButton(
                        text: 'Confirm & Complete Registration',
                        onPressed: handleConfirm,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ][currentStep.value],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
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
                  fontSize: 13,
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

class _FrequencyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrequencyTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : const Icon(Icons.radio_button_off, color: Colors.grey),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
