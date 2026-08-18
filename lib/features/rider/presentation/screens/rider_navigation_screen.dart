import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/shared/widgets/app_map.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../providers/rider_providers.dart';
import '../providers/rider_tracking_provider.dart';

/// Turn-by-turn navigation to a customer pickup, on a real Google map.
///
/// Position comes from the device GPS via [riderTrackingProvider], which also
/// mirrors every fix to Supabase so admin and the customer see the same
/// movement. The route itself comes from the Routes API when a key is
/// configured, and degrades to a straight line when it is not.
class RiderNavigationScreen extends ConsumerStatefulWidget {
  final PickupRequestEntity? pickup;

  const RiderNavigationScreen({super.key, this.pickup});

  @override
  ConsumerState<RiderNavigationScreen> createState() =>
      _RiderNavigationScreenState();
}

class _RiderNavigationScreenState extends ConsumerState<RiderNavigationScreen> {
  GoogleMapController? _mapController;
  final MarkerAnimator _riderAnimator = MarkerAnimator();

  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _destinationIcon;

  LatLng? _destination;
  bool _resolvingDestination = true;

  RouteResult? _route;
  bool _loadingRoute = false;

  /// Origin the current [_route] was computed from. A new route is only
  /// requested once the rider has moved meaningfully away from it, so a fix
  /// arriving every few seconds does not trigger a billed call every few
  /// seconds.
  LatLng? _routeOrigin;

  /// Whether the camera follows the rider. Panning the map by hand turns this
  /// off so the map stops fighting the rider's own gesture; the recentre button
  /// turns it back on.
  bool _followRider = true;

  LatLng? _renderedRiderPosition;
  double _renderedBearing = 0;
  bool _hasArrived = false;

  @override
  void initState() {
    super.initState();
    // Deferred: both touch provider state, which cannot be mutated during the
    // first build pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTracking();
      _resolveDestination();
    });
  }

  @override
  void dispose() {
    _riderAnimator.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    // The job id makes the tracker mirror fixes onto this pickup's row and
    // promotes Android to a foreground service, so tracking survives the rider
    // locking the phone or switching to another app mid-run.
    await ref.read(riderTrackingProvider.notifier).start(
          jobId: widget.pickup?.id,
        );
  }

  /// Works out where we are actually navigating to.
  ///
  /// Order matters: explicit coordinates on the request, then coordinates
  /// embedded in the location text (older rows), then a geocode of the address.
  /// If all three fail there is nothing to plot, and the UI says so instead of
  /// inventing a destination.
  Future<void> _resolveDestination() async {
    final pickup = widget.pickup;
    if (pickup == null) {
      if (mounted) setState(() => _resolvingDestination = false);
      return;
    }

    var destination = pickup.destination ?? GeoUtils.tryParseLatLng(pickup.location);

    if (destination == null && MapConfig.hasWebServiceKey) {
      destination = await DirectionsService.instance.geocodeAddress(pickup.location);
    }

    if (!mounted) return;
    setState(() {
      _destination = destination;
      _resolvingDestination = false;
    });

    await _loadMarkerIcons();
    _refreshRouteIfNeeded(force: true);
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

  /// Fetches a road route, but only when it would actually differ from the one
  /// already drawn.
  Future<void> _refreshRouteIfNeeded({bool force = false}) async {
    final destination = _destination;
    final origin = _renderedRiderPosition ?? ref.read(riderTrackingProvider).latLng;
    if (destination == null || origin == null || _loadingRoute) return;

    if (!force && _routeOrigin != null) {
      final drift = GeoUtils.distanceMeters(_routeOrigin!, origin);
      if (drift < MapConfig.routeRefreshThresholdMeters) return;
    }

    setState(() => _loadingRoute = true);

    final result = await DirectionsService.instance.getRoute(
      origin: origin,
      destination: destination,
      travelMode: _travelModeForVehicle(),
    );

    if (!mounted) return;
    setState(() {
      _route = result;
      _routeOrigin = origin;
      _loadingRoute = false;
    });
  }

  /// Motorbikes get TWO_WHEELER routing, which picks bike-legal roads and gives
  /// a far more realistic Accra ETA than car routing does.
  String _travelModeForVehicle() {
    final vehicle = ref.read(riderProfileProvider).value?.vehicleType.toLowerCase();
    if (vehicle == null) return 'DRIVE';
    if (vehicle.contains('bike') || vehicle.contains('motor')) return 'TWO_WHEELER';
    return 'DRIVE';
  }

  /// Reacts to a new GPS fix: animates the marker, follows with the camera,
  /// re-routes on meaningful drift, and flips to the arrived state.
  void _onNewFix(RiderTrackingState tracking) {
    final position = tracking.latLng;
    if (position == null) return;

    final previous = _riderAnimator.current;
    final bearing = tracking.heading ??
        (previous == null ? _renderedBearing : GeoUtils.bearingDegrees(previous, position));

    _riderAnimator.animateTo(
      target: position,
      targetBearing: bearing,
      onFrame: (animated, animatedBearing) {
        if (!mounted) return;
        setState(() {
          _renderedRiderPosition = animated;
          _renderedBearing = animatedBearing;
        });
        if (_followRider) _moveCamera(animated, animatedBearing);
      },
    );

    _refreshRouteIfNeeded();
    _checkArrival(position);
  }

  void _moveCamera(LatLng target, double bearing) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: MapConfig.navigationZoom,
          bearing: bearing,
          tilt: 45,
        ),
      ),
    );
  }

  /// 60 m is roughly "outside the right building" once GPS error is accounted
  /// for -- tight enough to be meaningful, loose enough not to require standing
  /// on the exact pin.
  void _checkArrival(LatLng position) {
    final destination = _destination;
    if (destination == null || _hasArrived) return;
    if (GeoUtils.distanceMeters(position, destination) <= 60) {
      setState(() => _hasArrived = true);
    }
  }

  Future<void> _recentre() async {
    setState(() => _followRider = true);
    final position = _renderedRiderPosition ?? ref.read(riderTrackingProvider).latLng;
    if (position != null) _moveCamera(position, _renderedBearing);
  }

  /// Frames the whole route so the rider can see the shape of the trip.
  Future<void> _showWholeRoute() async {
    final points = <LatLng>[
      ...?_route?.polyline,
      ?_renderedRiderPosition,
      ?_destination,
    ];
    final bounds = GeoUtils.boundsFor(points);
    if (bounds == null) return;

    setState(() => _followRider = false);
    await _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  /// Hands off to the Google Maps app for full voice navigation. Prefers real
  /// coordinates over the address string so the handoff lands on the same point
  /// the in-app map is showing.
  Future<void> _launchGoogleMaps() async {
    final destination = _destination;
    final query = destination != null
        ? '${destination.latitude},${destination.longitude}'
        : (widget.pickup?.location ?? '');

    if (query.isEmpty) {
      _showSnack('No destination coordinates to navigate to.');
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(query)}&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open the Google Maps app.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracking = ref.watch(riderTrackingProvider);

    // Drive the marker off each new fix. Done in a listener rather than in
    // build so the animation is not restarted by unrelated rebuilds.
    ref.listen<RiderTrackingState>(riderTrackingProvider, (previous, next) {
      if (previous?.position != next.position) _onNewFix(next);
    });

    final pickup = widget.pickup;
    final customerName = pickup?.customerName ?? 'Customer';
    final location = pickup?.location ?? 'Pickup location';
    final binTypes = (pickup?.binTypes.isNotEmpty ?? false)
        ? pickup!.binTypes.join(', ')
        : 'General Waste';
    final timeSlot = pickup?.timeSlot ?? 'Scheduled slot';

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
            _InstructionBanner(
              route: _route,
              hasArrived: _hasArrived,
              destinationLabel: location,
              isResolvingDestination: _resolvingDestination,
              hasDestination: _destination != null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      _buildMap(theme, tracking),
                      _GpsStatusChip(tracking: tracking),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            _MapActionButton(
                              icon: _followRider
                                  ? Icons.my_location
                                  : Icons.location_searching,
                              tooltip: _followRider
                                  ? 'Following your position'
                                  : 'Recentre on me',
                              active: _followRider,
                              onPressed: _recentre,
                            ),
                            const SizedBox(height: 8),
                            _MapActionButton(
                              icon: Icons.zoom_out_map,
                              tooltip: 'Show whole route',
                              onPressed: _showWholeRoute,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: _MetricsBar(
                          route: _route,
                          speedKmh: tracking.speedKmh,
                          isLoading: _loadingRoute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _BottomActionPanel(
              customerName: customerName,
              subtitle: '$binTypes • $timeSlot',
              onOpenGoogleMaps: _launchGoogleMaps,
              onStartCollection: () =>
                  context.push('/rider/collection', extra: widget.pickup),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(ThemeData theme, RiderTrackingState tracking) {
    if (tracking.isPermissionBlocked) {
      return _LocationBlockedNotice(access: tracking.access!);
    }

    final riderPosition = _renderedRiderPosition ?? tracking.latLng;
    final initialTarget = riderPosition ?? _destination ?? MapConfig.fallbackCenter;

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
        ),
      if (_destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: widget.pickup?.customerName ?? 'Pickup',
            snippet: widget.pickup?.location,
          ),
        ),
    };

    final polylines = <Polyline>{
      if (_route != null && _route!.polyline.length > 1)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _route!.polyline,
          color: theme.colorScheme.primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          // A dashed line signals "approximate" for the straight-line fallback,
          // so the rider is not led to believe it follows real roads.
          patterns: _route!.isFallback
              ? <PatternItem>[PatternItem.dash(24), PatternItem.gap(14)]
              : const <PatternItem>[],
        ),
    };

    final circles = <Circle>{
      if (_destination != null)
        Circle(
          circleId: const CircleId('arrival_zone'),
          center: _destination!,
          radius: 60,
          fillColor: theme.colorScheme.primary.withValues(alpha: 0.10),
          strokeColor: theme.colorScheme.primary.withValues(alpha: 0.45),
          strokeWidth: 2,
        ),
    };

    return Listener(
      // A drag on the map means the rider wants manual control; stop the camera
      // chasing them until they tap recentre.
      onPointerDown: (_) {
        if (_followRider) setState(() => _followRider = false);
      },
      child: AppMap(
        initialCameraPosition: CameraPosition(
          target: initialTarget,
          zoom: riderPosition != null
              ? MapConfig.navigationZoom
              : MapConfig.cityZoom,
        ),
        markers: markers,
        polylines: polylines,
        circles: circles,
        showCompass: true,
        onMapCreated: (controller) {
          _mapController = controller;
          if (riderPosition != null) _moveCamera(riderPosition, _renderedBearing);
        },
      ),
    );
  }
}

// ── Instruction banner ──────────────────────────────────────────────────────

class _InstructionBanner extends StatelessWidget {
  final RouteResult? route;
  final bool hasArrived;
  final String destinationLabel;
  final bool isResolvingDestination;
  final bool hasDestination;

  const _InstructionBanner({
    required this.route,
    required this.hasArrived,
    required this.destinationLabel,
    required this.isResolvingDestination,
    required this.hasDestination,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, headline) = _content();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasArrived ? const Color(0xFF2E7D32) : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: $destinationLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
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
    );
  }

  (IconData, String) _content() {
    if (hasArrived) {
      return (Icons.flag_rounded, 'You have arrived at the pickup location');
    }
    if (isResolvingDestination) {
      return (Icons.hourglass_top_rounded, 'Locating the pickup address…');
    }
    if (!hasDestination) {
      return (
        Icons.help_outline_rounded,
        'This request has no map coordinates — use the address below',
      );
    }

    final step = route?.nextStep;
    if (step != null) {
      return (_iconForManeuver(step.maneuver), '${step.instruction} (${step.distanceLabel})');
    }
    if (route?.isFallback ?? false) {
      return (
        Icons.near_me_rounded,
        'Head towards the pickup — direct distance shown below',
      );
    }
    return (Icons.navigation_rounded, 'Starting navigation…');
  }

  /// Maps the Routes API manoeuvre enum onto Material icons.
  IconData _iconForManeuver(String maneuver) {
    return switch (maneuver) {
      'TURN_LEFT' || 'TURN_SLIGHT_LEFT' || 'TURN_SHARP_LEFT' => Icons.turn_left_rounded,
      'TURN_RIGHT' || 'TURN_SLIGHT_RIGHT' || 'TURN_SHARP_RIGHT' => Icons.turn_right_rounded,
      'UTURN_LEFT' || 'UTURN_RIGHT' => Icons.u_turn_left_rounded,
      'MERGE' => Icons.merge_rounded,
      'ROUNDABOUT_LEFT' || 'ROUNDABOUT_RIGHT' => Icons.roundabout_left_rounded,
      'RAMP_LEFT' || 'RAMP_RIGHT' => Icons.ramp_left_rounded,
      'DEPART' => Icons.trip_origin_rounded,
      'DESTINATION' => Icons.flag_rounded,
      _ => Icons.straight_rounded,
    };
  }
}

// ── Map overlays ────────────────────────────────────────────────────────────

class _GpsStatusChip extends StatelessWidget {
  final RiderTrackingState tracking;
  const _GpsStatusChip({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (color, label) = switch (tracking) {
      _ when tracking.uploadError != null => (Colors.orange, tracking.uploadError!),
      _ when tracking.isBroadcasting && tracking.hasFix => (
          Colors.green,
          'Live • sharing with dispatch',
        ),
      _ when tracking.isBroadcasting => (Colors.orange, 'Acquiring GPS…'),
      _ => (Colors.grey, 'GPS off'),
    };

    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? Colors.black87 : Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: active ? theme.colorScheme.primary : theme.iconTheme.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricsBar extends StatelessWidget {
  final RouteResult? route;
  final double speedKmh;
  final bool isLoading;

  const _MetricsBar({
    required this.route,
    required this.speedKmh,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavMetricItem(
                label: 'DISTANCE',
                value: isLoading && route == null ? '—' : (route?.distanceLabel ?? '—'),
                color: theme.colorScheme.primary,
              ),
              _MetricDivider(),
              _NavMetricItem(
                label: 'EST. TIME',
                value: isLoading && route == null ? '—' : (route?.durationLabel ?? '—'),
                color: Colors.green,
              ),
              _MetricDivider(),
              _NavMetricItem(
                label: 'SPEED',
                value: '${speedKmh.toStringAsFixed(0)} km/h',
                color: Colors.blue,
              ),
            ],
          ),
          // Being explicit about the fallback matters: a straight-line ETA is
          // optimistic by definition, and a rider planning their day around it
          // deserves to know which number they are looking at.
          if (route?.isFallback ?? false) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 12, color: theme.hintColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Direct-line estimate — road routing unavailable',
                    style: TextStyle(fontSize: 10, color: theme.hintColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 24, width: 1, color: Colors.grey.shade400);
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

/// Shown in place of the map when the OS is withholding location. Each case
/// gets the action that actually resolves it -- re-prompting a permanently
/// denied permission does nothing, so that path goes to Settings instead.
class _LocationBlockedNotice extends ConsumerWidget {
  final LocationAccess access;
  const _LocationBlockedNotice({required this.access});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final (title, body, actionLabel) = switch (access) {
      LocationAccess.serviceDisabled => (
          'Location is switched off',
          'Turn on location services so the map can follow your route and '
              'dispatch can see where you are.',
          'Open location settings',
        ),
      LocationAccess.deniedForever => (
          'Location permission blocked',
          'CleanConnect needs location access to navigate. Enable it in your '
              'app settings, then come back to this screen.',
          'Open app settings',
        ),
      _ => (
          'Location permission needed',
          'Allow location access so we can guide you to the pickup and keep '
              'the customer updated.',
          'Grant permission',
        ),
    };

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, size: 44, color: theme.hintColor),
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
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              switch (access) {
                case LocationAccess.serviceDisabled:
                  await LocationService.instance.openLocationSettings();
                case LocationAccess.deniedForever:
                  await LocationService.instance.openAppSettings();
                case _:
                  await ref.read(riderTrackingProvider.notifier).retryPermission();
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _BottomActionPanel extends StatelessWidget {
  final String customerName;
  final String subtitle;
  final VoidCallback onOpenGoogleMaps;
  final VoidCallback onStartCollection;

  const _BottomActionPanel({
    required this.customerName,
    required this.subtitle,
    required this.onOpenGoogleMaps,
    required this.onStartCollection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: theme.colorScheme.primary),
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
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onOpenGoogleMaps,
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
                  onPressed: onStartCollection,
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
    );
  }
}
