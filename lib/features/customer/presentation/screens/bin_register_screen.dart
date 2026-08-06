import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';
import '../providers/customer_providers.dart';

enum _BinRegistrationMode { requestCompanyBin, personalBin }

class BinRegisterScreen extends HookConsumerWidget {
  const BinRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = useState<_BinRegistrationMode?>(null);
    final currentStep = useState(0);

    final selectedType = useState('recycling'); // 'recycling', 'organic'
    final selectedSize = useState('240L'); // '120L', '240L', '360L'
    final gpsLocation = useState('');
    final photoPath = useState<String?>(null);
    final photoBytes = useState<Uint8List?>(null);

    final selectedFrequency = useState('Weekly');
    final preferredDays = useState<List<String>>(['Monday']);

    final formKey = useMemoized(() => GlobalKey<FormState>());

    Future<void> detectLocation() async {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied ||
              requested == LocationPermission.deniedForever) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is denied.')),
            );
            return;
          }
        }
        gpsLocation.value = 'Fetching GPS coordinates...';
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        gpsLocation.value = _formatMapCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (_) {
        gpsLocation.value =
            '${_formatMapCoordinates(5.6037, -0.1870)} (Fallback)';
      }
    }

    Future<void> captureImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        photoPath.value = pickedFile.path;
        photoBytes.value = await pickedFile.readAsBytes();
      }
    }

    void handleSelectMode(_BinRegistrationMode mode) {
      selectedMode.value = mode;
      currentStep.value = 0;
      selectedType.value = 'recycling';
      selectedSize.value = '240L';
      gpsLocation.value = '';
      photoPath.value = null;
      photoBytes.value = null;
      selectedFrequency.value = 'Weekly';
      preferredDays.value = ['Monday'];
    }

    void handleNextStep() {
      if (selectedMode.value == null) return;
      if (currentStep.value == 0) {
        if (formKey.currentState?.validate() ?? false) {
          if (gpsLocation.value.isEmpty ||
              gpsLocation.value == 'Fetching GPS coordinates...') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please detect your GPS location.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          currentStep.value = 1;
        }
      } else if (currentStep.value == 1 &&
          selectedMode.value == _BinRegistrationMode.personalBin) {
        currentStep.value = 2;
      }
    }

    void handleBackStep() {
      if (selectedMode.value == null) {
        context.pop();
      } else if (currentStep.value > 0) {
        currentStep.value--;
      } else {
        selectedMode.value = null;
      }
    }

    Future<void> handleConfirm() async {
      try {
        if (selectedMode.value == _BinRegistrationMode.requestCompanyBin) {
          await ref.read(customerBinsProvider.notifier).requestCompanyBin(
                type: selectedType.value,
                size: selectedSize.value,
                gpsLocation: gpsLocation.value,
              );

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bin request submitted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final bin = await ref.read(customerBinsProvider.notifier).registerNewBin(
                type: selectedType.value,
                size: selectedSize.value,
                frequency: selectedFrequency.value,
                pickupDays: preferredDays.value,
                gpsLocation: gpsLocation.value,
                photoPath: photoPath.value,
              );

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Personal bin registered. Serial number: ${bin.serialNumber}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        if (context.mounted) context.pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to complete bin request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mode = selectedMode.value;
    final stepCount = mode == _BinRegistrationMode.personalBin ? 3 : 2;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Bin Registration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: handleBackStep,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: mode == null
            ? _RegistrationChoiceView(onSelect: handleSelectMode)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: List.generate(stepCount, (index) {
                        final isActive = currentStep.value >= index;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade200,
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
                      child: _stepContent(
                        mode: mode,
                        currentStep: currentStep.value,
                        formKey: formKey,
                        selectedType: selectedType,
                        selectedSize: selectedSize,
                        gpsLocation: gpsLocation,
                        photoPath: photoPath,
                        photoBytes: photoBytes,
                        selectedFrequency: selectedFrequency,
                        preferredDays: preferredDays,
                        isDark: isDark,
                        theme: theme,
                        detectLocation: detectLocation,
                        captureImage: captureImage,
                        handleNextStep: handleNextStep,
                        handleConfirm: handleConfirm,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stepContent({
    required _BinRegistrationMode mode,
    required int currentStep,
    required GlobalKey<FormState> formKey,
    required ValueNotifier<String> selectedType,
    required ValueNotifier<String> selectedSize,
    required ValueNotifier<String> gpsLocation,
    required ValueNotifier<String?> photoPath,
    required ValueNotifier<Uint8List?> photoBytes,
    required ValueNotifier<String> selectedFrequency,
    required ValueNotifier<List<String>> preferredDays,
    required bool isDark,
    required ThemeData theme,
    required Future<void> Function() detectLocation,
    required Future<void> Function() captureImage,
    required VoidCallback handleNextStep,
    required Future<void> Function() handleConfirm,
  }) {
    if (currentStep == 0) {
      return _BinDetailsStep(
        formKey: formKey,
        mode: mode,
        selectedType: selectedType,
        selectedSize: selectedSize,
        gpsLocation: gpsLocation,
        photoPath: photoPath,
        photoBytes: photoBytes,
        isDark: isDark,
        detectLocation: detectLocation,
        captureImage: captureImage,
        handleNextStep: handleNextStep,
      );
    }

    if (mode == _BinRegistrationMode.requestCompanyBin) {
      return _RequestReviewStep(
        selectedType: selectedType,
        selectedSize: selectedSize,
        gpsLocation: gpsLocation,
        handleConfirm: handleConfirm,
      );
    }

    if (currentStep == 1) {
      return _ScheduleStep(
        theme: theme,
        selectedFrequency: selectedFrequency,
        preferredDays: preferredDays,
        handleNextStep: handleNextStep,
      );
    }

    return _PersonalReviewStep(
      selectedType: selectedType,
      selectedSize: selectedSize,
      gpsLocation: gpsLocation,
      photoPath: photoPath,
      photoBytes: photoBytes,
      selectedFrequency: selectedFrequency,
      preferredDays: preferredDays,
      isDark: isDark,
      theme: theme,
      handleConfirm: handleConfirm,
    );
  }
}

class _RegistrationChoiceView extends StatelessWidget {
  final ValueChanged<_BinRegistrationMode> onSelect;

  const _RegistrationChoiceView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Choose Registration Type',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select whether you need a CleanConnect bin assigned or want to register your own bin.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _RegistrationModeCard(
          title: 'Request for Bin',
          subtitle: 'Ask admin to assign a company-owned bin with a serial number.',
          icon: Icons.inventory_2_outlined,
          iconColor: Colors.blue,
          onTap: () => onSelect(_BinRegistrationMode.requestCompanyBin),
        ),
        const SizedBox(height: 16),
        _RegistrationModeCard(
          title: 'Register Personal Bin',
          subtitle: 'Register your own bin. A serial number will be generated after submission.',
          icon: Icons.delete_outline,
          iconColor: Colors.green,
          onTap: () => onSelect(_BinRegistrationMode.personalBin),
        ),
      ],
    );
  }
}

class _BinDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _BinRegistrationMode mode;
  final ValueNotifier<String> selectedType;
  final ValueNotifier<String> selectedSize;
  final ValueNotifier<String> gpsLocation;
  final ValueNotifier<String?> photoPath;
  final ValueNotifier<Uint8List?> photoBytes;
  final bool isDark;
  final Future<void> Function() detectLocation;
  final Future<void> Function() captureImage;
  final VoidCallback handleNextStep;

  const _BinDetailsStep({
    required this.formKey,
    required this.mode,
    required this.selectedType,
    required this.selectedSize,
    required this.gpsLocation,
    required this.photoPath,
    required this.photoBytes,
    required this.isDark,
    required this.detectLocation,
    required this.captureImage,
    required this.handleNextStep,
  });

  @override
  Widget build(BuildContext context) {
    final isPersonal = mode == _BinRegistrationMode.personalBin;

    return Form(
      key: formKey,
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
          DropdownButtonFormField<String>(
            initialValue: selectedSize.value,
            decoration: const InputDecoration(labelText: 'Bin Capacity'),
            items: const [
              DropdownMenuItem(value: '120L', child: Text('120L Small')),
              DropdownMenuItem(value: '240L', child: Text('240L Large')),
              DropdownMenuItem(
                value: '360L',
                child: Text('360L Extra Large'),
              ),
            ],
            onChanged: (val) {
              if (val != null) selectedSize.value = val;
            },
          ),
          const SizedBox(height: 16),
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
          if (isPersonal) ...[
            const SizedBox(height: 12),
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
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: photoPath.value != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.memory(photoBytes.value!, fit: BoxFit.cover)
                            : Image.file(
                                File(photoPath.value!),
                                fit: BoxFit.cover,
                              ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Color(0xFFF0A500),
                            size: 30,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Take Photo of Bin',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          EcoButton(
            text: isPersonal ? 'Continue Registration' : 'Review Request',
            onPressed: handleNextStep,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  final ThemeData theme;
  final ValueNotifier<String> selectedFrequency;
  final ValueNotifier<List<String>> preferredDays;
  final VoidCallback handleNextStep;

  const _ScheduleStep({
    required this.theme,
    required this.selectedFrequency,
    required this.preferredDays,
    required this.handleNextStep,
  });

  @override
  Widget build(BuildContext context) {
    const days = [
      ('M', 'Monday'),
      ('T', 'Tuesday'),
      ('W', 'Wednesday'),
      ('T', 'Thursday'),
      ('F', 'Friday'),
      ('S', 'Saturday'),
      ('S', 'Sunday'),
    ];

    return Column(
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
          children: days.map((day) {
            final isSelected = preferredDays.value.contains(day.$2);
            return GestureDetector(
              onTap: () {
                preferredDays.value = [day.$2];
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    day.$1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        EcoButton(text: 'Next', onPressed: handleNextStep),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RequestReviewStep extends StatelessWidget {
  final ValueNotifier<String> selectedType;
  final ValueNotifier<String> selectedSize;
  final ValueNotifier<String> gpsLocation;
  final Future<void> Function() handleConfirm;

  const _RequestReviewStep({
    required this.selectedType,
    required this.selectedSize,
    required this.gpsLocation,
    required this.handleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Bin Request',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          'Admin will assign a company-owned bin and provide its serial number.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _SummaryCard(
          isDark: isDark,
          theme: theme,
          children: [
            _SummaryRow(
              icon: Icons.inventory_2_outlined,
              label: 'Requested Bin',
              value:
                  '${_formatWasteType(selectedType.value)} (${selectedSize.value})',
            ),
            const Divider(height: 24),
            _SummaryRow(
              icon: Icons.pin_outlined,
              label: 'Serial Number',
              value: 'Assigned by admin',
            ),
            const Divider(height: 24),
            _SummaryRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: gpsLocation.value,
            ),
          ],
        ),
        const SizedBox(height: 32),
        EcoButton(text: 'Submit Bin Request', onPressed: handleConfirm),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PersonalReviewStep extends StatelessWidget {
  final ValueNotifier<String> selectedType;
  final ValueNotifier<String> selectedSize;
  final ValueNotifier<String> gpsLocation;
  final ValueNotifier<String?> photoPath;
  final ValueNotifier<Uint8List?> photoBytes;
  final ValueNotifier<String> selectedFrequency;
  final ValueNotifier<List<String>> preferredDays;
  final bool isDark;
  final ThemeData theme;
  final Future<void> Function() handleConfirm;

  const _PersonalReviewStep({
    required this.selectedType,
    required this.selectedSize,
    required this.gpsLocation,
    required this.photoPath,
    required this.photoBytes,
    required this.selectedFrequency,
    required this.preferredDays,
    required this.isDark,
    required this.theme,
    required this.handleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Confirm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          'A serial number will be generated when registration is completed.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _SummaryCard(
          isDark: isDark,
          theme: theme,
          children: [
            _SummaryRow(
              icon: Icons.delete,
              label: 'Bin Details',
              value:
                  '${_formatWasteType(selectedType.value)} (${selectedSize.value})',
            ),
            const Divider(height: 24),
            const _SummaryRow(
              icon: Icons.pin_outlined,
              label: 'Serial Number',
              value: 'Generated after submission',
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
              value:
                  '${selectedFrequency.value} (${preferredDays.value.first})',
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
                        const Text(
                          'Verification Photo',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.memory(
                                  photoBytes.value!,
                                  height: 100,
                                  width: 150,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
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
        const SizedBox(height: 32),
        EcoButton(
          text: 'Confirm & Complete Registration',
          onPressed: handleConfirm,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

String _formatMapCoordinates(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

String _formatWasteType(String type) {
  return '${type[0].toUpperCase()}${type.substring(1)} Waste';
}

class _RegistrationModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _RegistrationModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? theme.cardTheme.color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
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
                icon,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
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

class _SummaryCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final List<Widget> children;

  const _SummaryCard({
    required this.isDark,
    required this.theme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
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
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
