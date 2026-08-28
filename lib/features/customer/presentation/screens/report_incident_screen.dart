import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/shared/widgets/clean_connect_button.dart';
import '../../../../core/shared/widgets/clean_connect_text_field.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
import 'location_picker_screen.dart';

class ReportIncidentScreen extends HookConsumerWidget {
  const ReportIncidentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIssueType = useState<String?>(null);
    final locationController = useTextEditingController();
    final isDetectingLocation = useState(false);
    final mediaPath = useState<String?>(null);
    final mediaBytes = useState<Uint8List?>(null);
    final mediaFileName = useState<String?>(null);
    final mediaType = useState<String?>(null); // 'photo' or 'video'
    final isSubmitting = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final currentUser = ref.watch(currentUserProvider);

    Future<void> detectLocation() async {
      isDetectingLocation.value = true;
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
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        locationController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not detect location automatically. Please type it in.',
            ),
          ),
        );
      } finally {
        isDetectingLocation.value = false;
      }
    }

    Future<void> chooseOnMap() async {
      LatLng initialPosition = MapConfig.fallbackCenter;
      final parsed = GeoUtils.tryParseLatLng(locationController.text);
      if (parsed != null) {
        initialPosition = parsed;
      } else {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          initialPosition = LatLng(position.latitude, position.longitude);
        } catch (_) {
          // Fall back to the default map center.
        }
      }

      if (!context.mounted) return;
      final result = await Navigator.of(context).push<PickedLocation>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(initialPosition: initialPosition),
        ),
      );
      if (result != null) {
        locationController.text = result.label?.trim().isNotEmpty == true
            ? result.label!.trim()
            : GeoUtils.formatCoordinates(
                result.position.latitude,
                result.position.longitude,
              );
      }
    }

    Future<void> pickMedia(String type) async {
      final picker = ImagePicker();
      final pickedFile = type == 'video'
          ? await picker.pickVideo(
              source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
            )
          : await picker.pickImage(
              source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 80,
            );
      if (pickedFile != null) {
        mediaPath.value = pickedFile.path;
        mediaBytes.value = await pickedFile.readAsBytes();
        mediaFileName.value = pickedFile.name;
        mediaType.value = type;
      }
    }

    Future<void> handleSubmit() async {
      if (!(formKey.currentState?.validate() ?? false)) return;

      isSubmitting.value = true;
      try {
        await ref.read(customerIncidentReportsProvider.notifier).submitReport(
              description: selectedIssueType.value!,
              location: locationController.text.trim(),
              mediaBytes: mediaBytes.value,
              mediaFileName: mediaFileName.value,
              mediaType: mediaType.value,
            );

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — your report has been submitted.'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to submit report: $e'),
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
          'Report an Issue',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spotted illegal dumping or a choked gutter?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let us know what you saw and where — a worker will be assigned to look into it.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Reporter info (auto-filled, read-only) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF3F7F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reporting as',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentUser?.fullName ?? 'Customer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if ((currentUser?.phoneNumber ?? '').isNotEmpty)
                              Text(
                                currentUser!.phoneNumber,
                                style: const TextStyle(
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
                  'What did you see?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedIssueType.value,
                  decoration: const InputDecoration(
                    hintText: 'Select an issue type',
                    prefixIcon: Icon(Icons.report_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Heaped Waste',
                      child: Text('Heaped Waste'),
                    ),
                    DropdownMenuItem(
                      value: 'Choked Gutter',
                      child: Text('Choked Gutter'),
                    ),
                  ],
                  onChanged: (val) => selectedIssueType.value = val,
                  validator: (value) =>
                      value == null ? 'Please select an issue type.' : null,
                ),
                const SizedBox(height: 20),

                CleanConnectTextField(
                  labelText: 'Location',
                  hintText: 'e.g. Near Achimota Market, opposite the pharmacy',
                  controller: locationController,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter the location.'
                      : null,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    icon: isDetectingLocation.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, color: Color(0xFFF0A500)),
                    onPressed: isDetectingLocation.value ? null : detectLocation,
                    tooltip: 'Auto-detect my location',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: chooseOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Choose on Map'),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Photo or Video (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (mediaPath.value != null)
                  Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFFFF7EA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: mediaType.value == 'video'
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam, size: 36, color: Colors.grey),
                                SizedBox(height: 6),
                                Text(
                                  'Video attached',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.memory(mediaBytes.value!, fit: BoxFit.cover)
                                : Image.file(File(mediaPath.value!), fit: BoxFit.cover),
                          ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickMedia('photo'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Add Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickMedia('video'),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Add Video'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                CleanConnectButton(
                  text: 'Submit Report',
                  isLoading: isSubmitting.value,
                  onPressed: handleSubmit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
