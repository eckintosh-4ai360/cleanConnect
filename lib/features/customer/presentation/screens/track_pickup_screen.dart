import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/shared/widgets/app_map.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/pickup_tracking_entity.dart';
import '../providers/customer_providers.dart';

/// Live map of the rider on their way to the customer.
///
/// Fed by the same `pickup_requests` row the rider's device writes to, over
/// Supabase Realtime -- so the marker moves because a real vehicle moved, not
/// on a timer.
class TrackPickupScreen extends ConsumerStatefulWidget {
  /// Request to follow. When null the screen follows whichever request is
  /// currently active, which is how it is opened from the dashboard banner.
  final String? requestId;

  const TrackPickupScreen({super.key, this.requestId});

  @override
  ConsumerState<TrackPickupScreen> createState() => _TrackPickupScreenState();
}

class _TrackPickupScreenState extends ConsumerState<TrackPickupScreen> {
  GoogleMapController? _mapController;
  final MarkerAnimator _riderAnimator = MarkerAnimator();

  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _destinationIcon;

  LatLng? _renderedRiderPosition;
  double _renderedBearing = 0;

  RouteResult? _route;
  LatLng? _routeOrigin;
  bool _loadingRoute = false;

  /// Set once the camera has framed rider + destination, so later position
  /// updates do not keep yanking the view back and fighting the customer's
  /// own panning.
  bool _hasFramedRoute = false;

  /// Guards the one-off geocode + write-back for legacy requests that were
  /// created before destination coordinates were captured.
  bool _attemptedDestinationRepair = false;

  /// Whether the first tracking value has been folded in. `ref.listen` only
  /// fires on *changes*, so a provider that already holds data -- the dashboard
  /// banner keeps `activePickupTrackingProvider` alive -- would deliver nothing
  /// until the next rider fix. With a stale or stationary rider that is never,
  /// leaving the ETA panel permanently blank.
  bool _seededFromFirstValue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMarkerIcons());
  }

  @override
  void dispose() {
    _riderAnimator.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    if (!mounted) return;
    final primary = Theme.of(context).colorScheme.primary;

    final rider = await MapMarkerIcons.instance.riderMarker(color: primary);
    final destination = await MapMarkerIcons.instance.destinationMarker(
      color: const Color(0xFFE53935),
    );

    if (!mounted) return;
    setState(() {
      _riderIcon = rider;
      _destinationIcon = destination;
    });
  }

  void _onTrackingUpdate(PickupTrackingEntity tracking) {
    _repairDestinationIfNeeded(tracking);

    if (!tracking.hasRiderPosition) return;
    final position = LatLng(tracking.riderLat!, tracking.riderLng!);

    final previous = _riderAnimator.current;
    final bearing = tracking.riderHeading ??
        (previous == null
            ? _renderedBearing
            : GeoUtils.bearingDegrees(previous, position));

    _riderAnimator.animateTo(
      target: position,
      targetBearing: bearing,
      onFrame: (animated, animatedBearing) {
        if (!mounted) return;
        setState(() {
          _renderedRiderPosition = animated;
          _renderedBearing = animatedBearing;
        });
      },
    );

    _refreshRoute(position, tracking);
  }

  /// A request booked before coordinates were captured has a plain address and
  /// nothing to plot. Geocode it once and write the result back, so every later
  /// open of this screen -- and the rider's navigation screen -- has a real
  /// destination.
  Future<void> _repairDestinationIfNeeded(PickupTrackingEntity tracking) async {
    if (_attemptedDestinationRepair || tracking.hasDestination) return;
    if (!MapConfig.hasWebServiceKey) return;
    _attemptedDestinationRepair = true;

    final parsed = GeoUtils.tryParseLatLng(tracking.location);
    final resolved = parsed ??
        await DirectionsService.instance.geocodeAddress(tracking.location);
    if (resolved == null || !mounted) return;

    // Straight to the repository rather than through pickupTrackingProvider:
    // when this screen is following the *active* request it has no id-keyed
    // provider open, and reaching for one would start a second Realtime
    // subscription purely to make a single RPC call.
    await ref.read(customerRepositoryProvider).setPickupDestination(
          requestId: tracking.requestId,
          latitude: resolved.latitude,
          longitude: resolved.longitude,
        );
  }

  Future<void> _refreshRoute(LatLng riderPosition, PickupTrackingEntity tracking) async {
    if (!tracking.hasDestination || _loadingRoute) return;

    if (_routeOrigin != null) {
      final drift = GeoUtils.distanceMeters(_routeOrigin!, riderPosition);
      if (drift < MapConfig.routeRefreshThresholdMeters) return;
    }

    setState(() => _loadingRoute = true);

    final result = await DirectionsService.instance.getRoute(
      origin: riderPosition,
      destination: LatLng(tracking.destinationLat!, tracking.destinationLng!),
      includeSteps: false,
    );

    if (!mounted) return;
    setState(() {
      _route = result;
      _routeOrigin = riderPosition;
      _loadingRoute = false;
    });

    if (!_hasFramedRoute) {
      _hasFramedRoute = true;
      _fitToRoute(tracking);
    }
  }

  Future<void> _fitToRoute(PickupTrackingEntity tracking) async {
    final points = <LatLng>[
      ...?_route?.polyline,
      ?_renderedRiderPosition,
      if (tracking.hasDestination)
        LatLng(tracking.destinationLat!, tracking.destinationLng!),
    ];
    final bounds = GeoUtils.boundsFor(points);
    if (bounds == null || _mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _callRider(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start a call to $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final asyncTracking = widget.requestId != null
        ? ref.watch(pickupTrackingProvider(widget.requestId!))
        : ref.watch(activePickupTrackingProvider);

    ref.listen(
      widget.requestId != null
          ? pickupTrackingProvider(widget.requestId!)
          : activePickupTrackingProvider,
      (previous, next) {
        final tracking = next.value;
        if (tracking != null) _onTrackingUpdate(tracking);
      },
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Track Your Pickup',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: asyncTracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CentredMessage(
          icon: Icons.error_outline,
          title: 'Could not load tracking',
          body: '$error',
        ),
        data: (tracking) {
          if (tracking == null) {
            return const _CentredMessage(
              icon: Icons.local_shipping_outlined,
              title: 'No active pickup',
              body: 'Book a collection and you will be able to follow your '
                  'rider here in real time.',
            );
          }
          if (!_seededFromFirstValue) {
            _seededFromFirstValue = true;
            // Post-frame: _onTrackingUpdate calls setState, which cannot run
            // during this build pass.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onTrackingUpdate(tracking);
            });
          }
          return _buildTracking(theme, tracking);
        },
      ),
    );
  }

  Widget _buildTracking(ThemeData theme, PickupTrackingEntity tracking) {
    return Column(
      children: [
        _PhaseBanner(tracking: tracking),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  _buildMap(theme, tracking),
                  if (tracking.isPositionStale)
                    const Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _StaleBanner(),
                    ),
                  if (tracking.hasRiderPosition && tracking.hasDestination)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'track_fit',
                        backgroundColor: theme.cardTheme.color,
                        foregroundColor: theme.colorScheme.primary,
                        tooltip: 'Show whole journey',
                        onPressed: () => _fitToRoute(tracking),
                        child: const Icon(Icons.zoom_out_map),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _RiderPanel(
          tracking: tracking,
          route: _route,
          onCall: _callRider,
        ),
      ],
    );
  }

  Widget _buildMap(ThemeData theme, PickupTrackingEntity tracking) {
    final destination = tracking.hasDestination
        ? LatLng(tracking.destinationLat!, tracking.destinationLng!)
        : null;
    final riderPosition = _renderedRiderPosition ??
        (tracking.hasRiderPosition
            ? LatLng(tracking.riderLat!, tracking.riderLng!)
            : null);

    if (destination == null && riderPosition == null) {
      return _CentredMessage(
        icon: Icons.map_outlined,
        title: tracking.isAssigned
            ? 'Waiting for your rider\'s location'
            : 'Waiting for a rider',
        body: tracking.isAssigned
            ? '${tracking.riderName ?? 'Your rider'} will appear on the map as '
                'soon as they start the trip.'
            : 'We will show the map here the moment a rider accepts your '
                'pickup.',
      );
    }

    final markers = <Marker>{
      if (riderPosition != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: riderPosition,
          icon: _riderIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _renderedBearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 2,
          infoWindow: InfoWindow(title: tracking.riderName ?? 'Your rider'),
        ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1.0),
          infoWindow: const InfoWindow(title: 'Your pickup location'),
        ),
    };

    final polylines = <Polyline>{
      if (_route != null && _route!.polyline.length > 1)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _route!.polyline,
          color: theme.colorScheme.primary,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: _route!.isFallback
              ? <PatternItem>[PatternItem.dash(20), PatternItem.gap(12)]
              : const <PatternItem>[],
        ),
    };

    return AppMap(
      initialCameraPosition: CameraPosition(
        target: riderPosition ?? destination!,
        zoom: MapConfig.trackingZoom,
      ),
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        if (!_hasFramedRoute) {
          _hasFramedRoute = true;
          _fitToRoute(tracking);
        }
      },
    );
  }
}

// ── Panels ──────────────────────────────────────────────────────────────────

class _PhaseBanner extends StatelessWidget {
  final PickupTrackingEntity tracking;
  const _PhaseBanner({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, icon, title, subtitle) = switch (tracking.phase) {
      PickupPhase.awaitingRider => (
          const Color(0xFFF0A500),
          Icons.hourglass_top_rounded,
          'Finding you a rider',
          'Your request is with our riders now.',
        ),
      PickupPhase.enRoute => (
          theme.colorScheme.primary,
          Icons.local_shipping_rounded,
          '${tracking.riderName ?? 'Your rider'} is on the way',
          tracking.location,
        ),
      PickupPhase.completed => (
          const Color(0xFF2E7D32),
          Icons.check_circle_rounded,
          'Pickup completed',
          'Thanks for keeping your community clean.',
        ),
      PickupPhase.cancelled => (
          Colors.grey,
          Icons.cancel_rounded,
          'Pickup cancelled',
          'This request is no longer active.',
        ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A frozen marker with no explanation reads as a broken app. This says plainly
/// that the last fix is old, so the customer knows the rider has not actually
/// been parked in one spot for ten minutes.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF57C00),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_statusbar_null, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Rider location paused — showing their last known position',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderPanel extends StatelessWidget {
  final PickupTrackingEntity tracking;
  final RouteResult? route;
  final Future<void> Function(String phone) onCall;

  const _RiderPanel({
    required this.tracking,
    required this.route,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (route != null && !tracking.isComplete) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TrackMetric(
                  label: 'ARRIVING IN',
                  value: route!.durationLabel,
                  color: theme.colorScheme.primary,
                ),
                Container(height: 26, width: 1, color: Colors.grey.shade300),
                _TrackMetric(
                  label: 'DISTANCE AWAY',
                  value: route!.distanceLabel,
                  color: Colors.blue,
                ),
                Container(height: 26, width: 1, color: Colors.grey.shade300),
                _TrackMetric(
                  label: 'UPDATED',
                  value: _updatedLabel(tracking.riderLocationUpdatedAt),
                  color: tracking.isPositionStale
                      ? const Color(0xFFF57C00)
                      : Colors.green,
                ),
              ],
            ),
            if (route!.isFallback) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 12, color: theme.hintColor),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Estimated in a straight line — road times may be longer',
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 26),
          ],
          if (tracking.isAssigned)
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  backgroundImage: tracking.riderPhotoUrl != null
                      ? NetworkImage(tracking.riderPhotoUrl!)
                      : null,
                  child: tracking.riderPhotoUrl == null
                      ? Icon(Icons.person, color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracking.riderName ?? 'Your rider',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (tracking.riderRating != null) ...[
                            const Icon(Icons.star, size: 13, color: Color(0xFFF0A500)),
                            const SizedBox(width: 3),
                            Text(
                              tracking.riderRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (tracking.vehicleType != null)
                            Flexible(
                              child: Text(
                                tracking.vehicleType!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (tracking.riderPhone != null)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'Call ${tracking.riderName ?? 'rider'}',
                    onPressed: () => onCall(tracking.riderPhone!),
                    icon: const Icon(Icons.phone),
                  ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.schedule, color: theme.hintColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We will introduce you to your rider as soon as one accepts.',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _updatedLabel(DateTime? at) {
    if (at == null) return '—';
    final elapsed = DateTime.now().difference(at);
    if (elapsed.inSeconds < 60) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    return DateFormat.Hm().format(at.toLocal());
  }
}

class _TrackMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TrackMetric({
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
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CentredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _CentredMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.hintColor),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
