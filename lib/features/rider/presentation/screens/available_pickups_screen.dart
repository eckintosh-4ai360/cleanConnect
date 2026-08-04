import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';
import '../../domain/entities/pickup_request_entity.dart';

class AvailablePickupsScreen extends ConsumerWidget {
  const AvailablePickupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupsAsync = ref.watch(availablePickupsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Available Pickups',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: pickupsAsync.when(
        data: (pickups) {
          if (pickups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: 52,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Pending Pickups',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New customer pickup requests\nwill appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: () async =>
                ref.invalidate(availablePickupsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pickups.length,
              itemBuilder: (context, index) {
                final pickup = pickups[index];
                return _PickupCard(
                  pickup: pickup,
                  isDark: isDark,
                  theme: theme,
                  onAccept: () => _onAccept(context, ref, pickup),
                  onReject: () => _onReject(context, ref, pickup),
                );
              },
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load pickups.\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Future<void> _onAccept(
    BuildContext context,
    WidgetRef ref,
    PickupRequestEntity pickup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Pickup'),
        content: Text(
          'Accept pickup for ${pickup.customerName} at ${pickup.location}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(availablePickupsProvider.notifier).accept(
              pickup.id,
              pickup.customerId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Pickup accepted! Starting Navigation...'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.push('/rider/navigation', extra: pickup);
        }
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

class _PickupCard extends StatelessWidget {
  final PickupRequestEntity pickup;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PickupCard({
    required this.pickup,
    required this.isDark,
    required this.theme,
    required this.onAccept,
    required this.onReject,
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
    final timeStr = DateFormat('MMM d • h:mm a').format(pickup.createdAt);
    final primaryBinType =
        pickup.binTypes.isNotEmpty ? pickup.binTypes.first : 'general';

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
                  color: Colors.black.withOpacity(0.04),
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
                    color: _binColor(primaryBinType).withOpacity(0.12),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0A500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF0A500),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Location ──────────────────────────────────────────────
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
                        color: _binColor(t).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _binColor(t).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_binIcon(t),
                              size: 12, color: _binColor(t)),
                          const SizedBox(width: 4),
                          Text(
                            t[0].toUpperCase() + t.substring(1),
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
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Pass',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Accept Pickup',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
