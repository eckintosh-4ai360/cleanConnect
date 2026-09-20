import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/pickup_discovery_provider.dart';
import '../providers/rider_providers.dart';
import '../providers/rider_tracking_provider.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../../../core/shared/widgets/house_photo_thumbnail.dart';

/// Pickups a rider can take.
///
/// "Now" holds on-demand requests and scheduled pickups whose slot is about to
/// start (or has), plus the rider's own claimed scheduled pickups that are due.
/// "Upcoming" holds the next few days of scheduled subscription pickups: open
/// ones to claim ahead of time, and the ones this rider already claimed.
///
/// Open pickups are scoped to the ones near this rider — see [nearbyPickups].
/// The rider's own claimed pickups never are: those are already theirs.
class AvailablePickupsScreen extends HookConsumerWidget {
  const AvailablePickupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupsAsync = ref.watch(availablePickupsProvider);
    final acceptedAsync = ref.watch(riderAcceptedPickupsProvider);
    final discovery = ref.watch(nearbyPickupsProvider);
    final origin = ref.watch(riderOriginProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Opened from a "scheduled pickup starts now" alarm: the rider is here, so
    // the ringing can stop.
    useEffect(() {
      NotificationService.instance.stopIncomingPickupAlert();
      return null;
    }, const []);

    double? distanceTo(PickupRequestEntity pickup) {
      final destination = pickup.destination;
      if (origin == null || destination == null) return null;
      return GeoUtils.distanceMeters(origin, destination);
    }

    final pending = <PickupRequestEntity>[
      for (final n in discovery.pickups) n.pickup,
    ];
    final mine = acceptedAsync.value ?? const <PickupRequestEntity>[];

    final nowOpen = pending.where((p) => !p.isUpcoming).toList()
      ..sort(_bySlotThenCreated);
    final myDueScheduled = mine.where((p) => p.isScheduled && !p.isUpcoming).toList()
      ..sort(_bySlotThenCreated);
    final upcomingOpen = pending.where((p) => p.isUpcoming).toList()..sort(_bySlotThenCreated);
    final myUpcoming = mine.where((p) => p.isUpcoming).toList()..sort(_bySlotThenCreated);

    Widget body(Widget Function() content) => pickupsAsync.when(
          data: (_) => content(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Failed to load pickups.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );

    Future<void> refresh() async {
      ref.invalidate(availablePickupsProvider);
      ref.invalidate(riderAcceptedPickupsProvider);
      // Picks up a radius an admin has since changed.
      ref.invalidate(pickupDiscoveryRadiusKmProvider);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar: const RiderBottomNavBar(currentIndex: 1),
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Pickups',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          actions: const [ThemeToggleButton(), SizedBox(width: 8)],
          bottom: TabBar(
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Now (${nowOpen.length + myDueScheduled.length})'),
              Tab(text: 'Upcoming (${upcomingOpen.length + myUpcoming.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            body(() {
              if (nowOpen.isEmpty && myDueScheduled.isEmpty) {
                return _EmptyState(
                  isDark: isDark,
                  title: 'No Pending Pickups',
                  message: discovery.outOfRangeCount > 0
                      ? 'Nothing within ${_km(discovery.radiusKm)} of you.\n'
                          '${discovery.outOfRangeCount} open request'
                          '${discovery.outOfRangeCount == 1 ? ' is' : 's are'} '
                          'further out — riders nearer to them get those first.'
                      : 'New customer pickup requests\nwithin ${_km(discovery.radiusKm)} of you\nwill appear here.',
                  onRefresh: refresh,
                  banner: _RangeNotice(discovery: discovery),
                );
              }
              return RefreshIndicator(
                color: theme.colorScheme.primary,
                onRefresh: refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _RangeNotice(discovery: discovery),
                    if (myDueScheduled.isNotEmpty) ...[
                      const _SectionHeader('Your scheduled pickups — due now'),
                      ...myDueScheduled.map(
                        (pickup) => _PickupCard(
                          pickup: pickup,
                          isDark: isDark,
                          theme: theme,
                          distanceMeters: distanceTo(pickup),
                          primaryLabel: 'Start Navigation',
                          primaryIcon: Icons.navigation_outlined,
                          onPrimary: () => context.push('/rider/navigation', extra: pickup),
                        ),
                      ),
                    ],
                    if (nowOpen.isNotEmpty && myDueScheduled.isNotEmpty)
                      const _SectionHeader('Open requests'),
                    ...nowOpen.map(
                      (pickup) => _PickupCard(
                        pickup: pickup,
                        isDark: isDark,
                        theme: theme,
                        distanceMeters: distanceTo(pickup),
                        primaryLabel: 'Accept Pickup',
                        primaryIcon: Icons.check_circle_outline,
                        onPrimary: () => _onAccept(context, ref, pickup),
                        secondaryLabel: 'Pass',
                        onSecondary: () => _onReject(context, ref, pickup),
                      ),
                    ),
                  ],
                ),
              );
            }),
            body(() {
              if (upcomingOpen.isEmpty && myUpcoming.isEmpty) {
                return _EmptyState(
                  isDark: isDark,
                  title: 'Nothing Scheduled Yet',
                  message:
                      'Subscription pickups for the next 3 days\nwithin ${_km(discovery.radiusKm)} of you\nappear here for you to claim.',
                  onRefresh: refresh,
                );
              }
              return RefreshIndicator(
                color: theme.colorScheme.primary,
                onRefresh: refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (myUpcoming.isNotEmpty) ...[
                      const _SectionHeader('Claimed by you'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'You get a reminder the evening before and an alarm when each slot starts.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      ...myUpcoming.map(
                        (pickup) => _PickupCard(
                          pickup: pickup,
                          isDark: isDark,
                          theme: theme,
                          distanceMeters: distanceTo(pickup),
                          claimedByMe: true,
                          primaryLabel: 'Claimed',
                          primaryIcon: Icons.event_available_outlined,
                          onPrimary: null,
                          secondaryLabel: 'Release',
                          onSecondary: () => _onRelease(context, ref, pickup),
                        ),
                      ),
                    ],
                    ..._groupByDay(upcomingOpen).entries.expand(
                          (entry) => [
                            _SectionHeader('Open — ${entry.key}'),
                            ...entry.value.map(
                              (pickup) => _PickupCard(
                                pickup: pickup,
                                isDark: isDark,
                                theme: theme,
                                distanceMeters: distanceTo(pickup),
                                primaryLabel: 'Claim',
                                primaryIcon: Icons.event_available_outlined,
                                onPrimary: () => _onAccept(context, ref, pickup),
                                secondaryLabel: 'Pass',
                                onSecondary: () => _onReject(context, ref, pickup),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// "4 km" / "3.5 km" — no trailing zero on a whole number of kilometres.
  static String _km(double km) =>
      '${km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';

  static int _bySlotThenCreated(PickupRequestEntity a, PickupRequestEntity b) {
    final aAt = a.slotStartsAt ?? a.createdAt;
    final bAt = b.slotStartsAt ?? b.createdAt;
    return aAt.compareTo(bAt);
  }

  static Map<String, List<PickupRequestEntity>> _groupByDay(List<PickupRequestEntity> pickups) {
    final groups = <String, List<PickupRequestEntity>>{};
    for (final p in pickups) {
      final at = p.slotStartsAt ?? p.createdAt;
      groups.putIfAbsent(DateFormat('EEEE d MMM').format(at), () => []).add(p);
    }
    return groups;
  }

  Future<void> _onAccept(
    BuildContext context,
    WidgetRef ref,
    PickupRequestEntity pickup,
  ) async {
    final upcoming = pickup.isUpcoming;
    final when = pickup.slotStartsAt == null
        ? ''
        : ' on ${DateFormat('EEE d MMM').format(pickup.slotStartsAt!)} (${pickup.timeSlot})';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(upcoming ? 'Claim Scheduled Pickup' : 'Accept Pickup'),
        content: Text(
          upcoming
              ? 'Claim the pickup for ${pickup.customerName} at ${pickup.location}$when? '
                  'You will get a reminder the evening before and an alarm when the slot starts. '
                  'You can release it before then if your plans change.'
              : 'Accept pickup for ${pickup.customerName} at ${pickup.location}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(upcoming ? 'Claim' : 'Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(availablePickupsProvider.notifier).accept(
            pickup.id,
            pickup.customerId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(upcoming
              ? '✅ Claimed. It is in your Upcoming list.'
              : '✅ Pickup accepted! Starting Navigation...'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (!upcoming) context.push('/rider/navigation', extra: pickup);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onRelease(
    BuildContext context,
    WidgetRef ref,
    PickupRequestEntity pickup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Pickup'),
        content: Text(
          'Give the pickup for ${pickup.customerName} back to other riders?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(availablePickupsProvider.notifier).release(pickup.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Released. Other riders can now claim it.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onReject(
    BuildContext context,
    WidgetRef ref,
    PickupRequestEntity pickup,
  ) async {
    try {
      await ref.read(availablePickupsProvider.notifier).reject(
            pickup.id,
            pickup.customerId,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request passed.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;

  /// Shown above the illustration. An empty list is exactly when the reason for
  /// it matters most, so the range notice belongs here too.
  final Widget? banner;

  const _EmptyState({
    required this.isDark,
    required this.title,
    required this.message,
    required this.onRefresh,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (banner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: banner!,
            ),
          const SizedBox(height: 120),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Why this list is as short as it is.
///
/// Riders used to see every open request in the country, so an unexplained
/// short list now reads as a bug. This says which of the two things is going on:
/// the list is scoped to what is near them, or dispatch cannot place them at all
/// and is therefore not ringing their phone for anything.
class _RangeNotice extends ConsumerWidget {
  const _RangeNotice({required this.discovery});

  final PickupDiscovery discovery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(riderTrackingProvider);
    final blocked = tracking.isPermissionBlocked;
    final located = discovery.riderLocated;

    if (located && discovery.outOfRangeCount == 0 && !blocked) {
      return const SizedBox.shrink();
    }

    final warn = blocked || !located;
    final color = warn ? Colors.orange : Colors.blueGrey;
    final radius = AvailablePickupsScreen._km(discovery.radiusKm);

    final String message;
    if (blocked) {
      message = 'Location is off, so dispatch cannot tell which pickups are '
          'near you — and new requests are only sent to riders within $radius '
          'of the customer. Turn location on to get your share of the work.';
    } else if (!located) {
      message = 'Dispatch has no position for you yet. New requests go to '
          'riders within $radius of the customer, so this list is showing '
          'everything until your location comes through.';
    } else {
      final n = discovery.outOfRangeCount;
      message = 'Showing pickups within $radius of you. '
          '$n other${n == 1 ? '' : 's'} ${n == 1 ? 'is' : 'are'} further out, '
          'closer to another rider.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warn ? Icons.location_off_outlined : Icons.my_location_outlined,
            size: 18,
            color: color.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: color.shade800, height: 1.4),
                ),
                if (blocked) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final access = await ref
                          .read(riderTrackingProvider.notifier)
                          .retryPermission();
                      if (access == LocationAccess.deniedForever) {
                        await LocationService.instance.openAppSettings();
                      } else if (access == LocationAccess.serviceDisabled) {
                        await LocationService.instance.openLocationSettings();
                      }
                    },
                    child: const Text('Turn on location'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final PickupRequestEntity pickup;
  final bool isDark;
  final ThemeData theme;

  /// Straight-line metres from the rider, or null when either end has no
  /// coordinates.
  final double? distanceMeters;

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool claimedByMe;

  const _PickupCard({
    required this.pickup,
    required this.isDark,
    required this.theme,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.distanceMeters,
    this.secondaryLabel,
    this.onSecondary,
    this.claimedByMe = false,
  });

  Color _binColor(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Colors.blue;
      case 'organic':
        return Colors.green;
      case 'hazardous':
        return Colors.red;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _binIcon(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Icons.recycling;
      case 'organic':
        return Icons.eco_outlined;
      case 'hazardous':
        return Icons.warning_amber_outlined;
      default:
        return Icons.delete_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = pickup.isScheduled && pickup.slotStartsAt != null
        ? 'Scheduled • ${DateFormat('EEE d MMM').format(pickup.slotStartsAt!)}'
        : DateFormat('MMM d • h:mm a').format(pickup.createdAt);
    final primaryBinType =
        pickup.binTypes.isNotEmpty ? pickup.binTypes.first : 'general';
    final statusLabel = claimedByMe ? 'Claimed' : (pickup.status == 'accepted' ? 'Yours' : 'Pending');
    final statusColor = claimedByMe || pickup.status == 'accepted'
        ? const Color(0xFF1DB954)
        : const Color(0xFFF0A500);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _binColor(primaryBinType).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _binIcon(primaryBinType),
                    color: _binColor(primaryBinType),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pickup.isScheduled ? Colors.purple.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pickup.isScheduled ? 'Subscription' : '3-Day Grace Period',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: pickup.isScheduled ? Colors.purple : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── House photo + location ────────────────────────────────
            // The photo the customer registered with. A GPS pin can be tens of
            // metres out, so this is what actually tells the rider which
            // building to walk up to. Tap to open it full-screen.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pickup.housePhotoUrl != null &&
                    pickup.housePhotoUrl!.trim().isNotEmpty) ...[
                  HousePhotoThumbnail(photoUrl: pickup.housePhotoUrl, size: 64),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pickup.location,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // How far the job is, straight-line. The first thing
                          // a rider weighs before accepting.
                          if (distanceMeters != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me_outlined,
                                    size: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    GeoUtils.formatDistance(distanceMeters!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (pickup.housePhotoUrl != null &&
                          pickup.housePhotoUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tap photo to enlarge',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Time slot ─────────────────────────────────────────────
            if (pickup.timeSlot.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    pickup.timeSlot,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Bin type chips ────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pickup.binTypes
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _binColor(t).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _binColor(t).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_binIcon(t),
                              size: 12, color: _binColor(t)),
                          const SizedBox(width: 4),
                          Text(
                            t.isEmpty ? t : t[0].toUpperCase() + t.substring(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _binColor(t),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // ── Action buttons ────────────────────────────────────────
            Row(
              children: [
                if (secondaryLabel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(primaryIcon, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          primaryLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
