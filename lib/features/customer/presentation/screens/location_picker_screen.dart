import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/shared/widgets/app_map.dart';

/// Result handed back to [PickupRequestScreen]: the pin the customer dropped,
/// plus whatever human-readable label could be resolved for it.
class PickedLocation {
  final LatLng position;
  final String? label;

  const PickedLocation({required this.position, this.label});
}

/// Full-screen pin-drop picker. This is the only way (besides "use my current
/// location") a customer can set a pickup address -- riders navigate off the
/// coordinates, so a typo-prone text field would put them at the wrong door.
/// Picking on the map is also what makes it possible to schedule a pickup for
/// someone else's address, since "current location" only ever covers the
/// customer's own position.
class LocationPickerScreen extends HookConsumerWidget {
  final LatLng initialPosition;

  const LocationPickerScreen({super.key, required this.initialPosition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = useState<LatLng>(initialPosition);
    final mapController = useState<GoogleMapController?>(null);
    final isLocating = useState(false);
    final resolvedLabel = useState<String?>(null);
    final isResolvingLabel = useState(false);

    Future<void> resolveLabel(LatLng point) async {
      isResolvingLabel.value = true;
      final label = await DirectionsService.instance.reverseGeocode(point);
      // Only apply if the pin hasn't moved again while this was in flight.
      if (selected.value == point) {
        resolvedLabel.value = label;
        isResolvingLabel.value = false;
      }
    }

    void movePin(LatLng point) {
      selected.value = point;
      resolvedLabel.value = null;
      resolveLabel(point);
    }

    // Resolve a label for the starting pin too.
    useEffect(() {
      resolveLabel(initialPosition);
      return null;
    }, const []);

    Future<void> useCurrentLocation() async {
      isLocating.value = true;
      final access = await LocationService.instance.ensurePermission();

      if (!context.mounted) return;

      switch (access) {
        case LocationAccess.granted:
          final position = await LocationService.instance.currentPosition();
          if (position != null) {
            final point = LatLng(position.latitude, position.longitude);
            movePin(point);
            await mapController.value?.animateCamera(
              CameraUpdate.newLatLngZoom(point, MapConfig.navigationZoom),
            );
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

    final marker = Marker(
      markerId: const MarkerId('picked_location'),
      position: selected.value,
      draggable: true,
      onDragEnd: movePin,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose Pickup Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AppMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: MapConfig.navigationZoom,
                  ),
                  markers: {marker},
                  onMapCreated: (c) => mapController.value = c,
                  onTap: movePin,
                  showZoomControls: true,
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'use-current-location',
                    onPressed: isLocating.value ? null : useCurrentLocation,
                    child: isLocating.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tap the map, or drag the pin, to mark the exact pickup spot.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: isResolvingLabel.value
                            ? const Text(
                                'Locating address…',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              )
                            : Text(
                                resolvedLabel.value ??
                                    '${selected.value.latitude.toStringAsFixed(6)}, '
                                        '${selected.value.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        PickedLocation(
                          position: selected.value,
                          label: resolvedLabel.value,
                        ),
                      ),
                      child: const Text('Confirm This Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
