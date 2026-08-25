import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/shared/widgets/app_map.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/customer_entities.dart';

/// Displays customer's registered bins on a map with company vs personal markers
class BinsMapView extends HookWidget {
  final List<BinEntity> bins;

  const BinsMapView({super.key, required this.bins});

  static const _companyColor = Color(0xFF2E7D32); // green
  static const _personalColor = Color(0xFF1565C0); // blue

  @override
  Widget build(BuildContext context) {
    final mappableBins = useMemoized(
      () => bins
          .map((bin) => (bin: bin, position: GeoUtils.tryParseLatLng(bin.gpsLocation)))
          .where((entry) => entry.position != null)
          .toList(),
      [bins],
    );

    final markers = useState<Set<Marker>>({});
    final mapController = useState<GoogleMapController?>(null);

    useEffect(() {
      Future<void> buildMarkers() async {
        final built = <Marker>{};
        for (final entry in mappableBins) {
          final bin = entry.bin;
          final isPersonal = bin.isPersonal;
          final icon = await MapMarkerIcons.instance.numberedPin(
            color: isPersonal ? _personalColor : _companyColor,
            label: isPersonal ? 'P' : 'C',
          );
          built.add(
            Marker(
              markerId: MarkerId(bin.id),
              position: entry.position!,
              icon: icon,
              anchor: const Offset(0.5, 1.0),
              infoWindow: InfoWindow(
                title: bin.serialNumber,
                snippet:
                    '${isPersonal ? "Personal" : "Company"} bin • ${bin.type} • ${bin.size}',
              ),
            ),
          );
        }
        markers.value = built;

        final bounds = GeoUtils.boundsFor(
          mappableBins.map((entry) => entry.position!),
        );
        final controller = mapController.value;
        if (bounds != null && controller != null) {
          if (mappableBins.length == 1) {
            await controller.animateCamera(
              CameraUpdate.newLatLngZoom(
                mappableBins.first.position!,
                MapConfig.cityZoom,
              ),
            );
          } else {
            await controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 56),
            );
          }
        }
      }

      buildMarkers();
      return null;
      // Re-fit camera when map controller initializes
    }, [mappableBins, mapController.value]);

    if (mappableBins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                bins.isEmpty
                    ? 'No bins registered yet.'
                    : 'None of your bins have a mappable location yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        AppMap(
          initialCameraPosition: CameraPosition(
            target: mappableBins.first.position!,
            zoom: MapConfig.cityZoom,
          ),
          markers: markers.value,
          showZoomControls: true,
          onMapCreated: (controller) => mapController.value = controller,
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _Legend(hiddenCount: bins.length - mappableBins.length),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final int hiddenCount;

  const _Legend({required this.hiddenCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LegendDot(color: BinsMapView._companyColor),
              const SizedBox(width: 6),
              const Text('Company Bin (CCB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              const _LegendDot(color: BinsMapView._personalColor),
              const SizedBox(width: 6),
              const Text('Personal Bin (PB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$hiddenCount bin${hiddenCount == 1 ? '' : 's'} without a saved location not shown.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
