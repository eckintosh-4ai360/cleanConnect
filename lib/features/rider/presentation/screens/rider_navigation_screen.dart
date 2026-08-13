import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../providers/rider_providers.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderNavigationScreen extends ConsumerStatefulWidget {
  final PickupRequestEntity? pickup;

  const RiderNavigationScreen({super.key, this.pickup});

  @override
  ConsumerState<RiderNavigationScreen> createState() =>
      _RiderNavigationScreenState();
}

class _RiderNavigationScreenState
    extends ConsumerState<RiderNavigationScreen> {
  // Start near Accra / Eco City coordinates
  double _currentLat = 5.6037;
  double _currentLng = -0.1870;
  // Destination coordinates
  final double _targetLat = 5.6200;
  final double _targetLng = -0.1700;

  bool _isSimulating = false;
  Timer? _simulationTimer;
  double _distanceKm = 2.4;
  int _etaMins = 8;
  double _speedKmh = 28.5;
  String _currentStep = 'Head north on Eco Avenue towards Green Street (400m)';

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _toggleMovementSimulation() {
    setState(() {
      _isSimulating = !_isSimulating;
    });

    if (_isSimulating) {
      _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;
        setState(() {
          if ((_targetLat - _currentLat).abs() > 0.0005) {
            _currentLat += (_targetLat > _currentLat ? 0.0010 : -0.0010);
          }
          if ((_targetLng - _currentLng).abs() > 0.0005) {
            _currentLng += (_targetLng > _currentLng ? 0.0010 : -0.0010);
          }

          if (_distanceKm > 0.3) {
            _distanceKm = double.parse((_distanceKm - 0.3).toStringAsFixed(1));
            _etaMins = (_distanceKm * 3.5).ceil();
          } else {
            _distanceKm = 0.1;
            _etaMins = 1;
            _currentStep = 'You have arrived at the customer pickup location!';
          }
        });

        // Transmit updated coordinates to Firestore for live Admin tracking
        ref.read(riderProfileProvider.notifier).updateLocation(
              latitude: _currentLat,
              longitude: _currentLng,
              heading: 45.0,
              speed: _speedKmh,
              currentJobId: widget.pickup?.id,
            );
      });
    } else {
      _simulationTimer?.cancel();
    }
  }

  Future<void> _launchGoogleMaps() async {
    final destination = Uri.encodeComponent(
      widget.pickup?.location ?? '123 Green St, Eco City',
    );
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final customerName = widget.pickup?.customerName ?? 'Sarah Jenkins';
    final location = widget.pickup?.location ?? 'Home: 123 Green St, Eco City';
    final binTypes = (widget.pickup?.binTypes != null && widget.pickup!.binTypes.isNotEmpty)
        ? widget.pickup!.binTypes.join(', ')
        : 'General Waste';
    final timeSlot = widget.pickup?.timeSlot ?? '08:00 AM - 12:00 PM';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rider Navigation',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'En route to $customerName',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.turn_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStep,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Target: $location',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: _NavigationPainter(
                          riderLat: _currentLat,
                          riderLng: _currentLng,
                          targetLat: _targetLat,
                          targetLng: _targetLng,
                          isDark: isDark,
                          accentColor: theme.colorScheme.primary,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black87
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isSimulating ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isSimulating ? 'GPS Streaming Live' : 'GPS Ready',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 12,
                      right: 12,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSimulating
                              ? Colors.red
                              : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _toggleMovementSimulation,
                        icon: Icon(
                          _isSimulating
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          _isSimulating ? 'Stop Sim' : 'Simulate Drive',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.85)
                              : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NavMetricItem(
                              label: 'DISTANCE',
                              value: '$_distanceKm km',
                              color: theme.colorScheme.primary,
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey.shade400,
                            ),
                            _NavMetricItem(
                              label: 'EST. TIME',
                              value: '$_etaMins min',
                              color: Colors.green,
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey.shade400,
                            ),
                            _NavMetricItem(
                              label: 'SPEED',
                              value: '${_speedKmh.toStringAsFixed(0)} km/h',
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.15),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '$binTypes • $timeSlot',
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
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _launchGoogleMaps,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text(
                            'Google Maps',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            context.push('/rider/collection', extra: widget.pickup);
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text(
                            'Start Collection',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NavMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NavigationPainter extends CustomPainter {
  final double riderLat;
  final double riderLng;
  final double targetLat;
  final double targetLng;
  final bool isDark;
  final Color accentColor;

  _NavigationPainter({
    required this.riderLat,
    required this.riderLng,
    required this.targetLat,
    required this.targetLng,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E242B) : const Color(0xFFE5E9F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.white
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path();
    routePath.moveTo(size.width * 0.25, size.height * 0.8);
    routePath.cubicTo(
      size.width * 0.35,
      size.height * 0.5,
      size.width * 0.65,
      size.height * 0.6,
      size.width * 0.75,
      size.height * 0.2,
    );

    canvas.drawPath(routePath, roadPaint);

    final activePathPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, activePathPaint);

    final riderPos = Offset(size.width * 0.25, size.height * 0.8);
    final riderPulsePaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(riderPos, 20, riderPulsePaint);

    final riderPinPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(riderPos, 10, riderPinPaint);

    final targetPos = Offset(size.width * 0.75, size.height * 0.2);
    final destPinPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(targetPos, 12, destPinPaint);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(targetPos, 5, whitePaint);
  }

  @override
  bool shouldRepaint(covariant _NavigationPainter oldDelegate) => true;
}
