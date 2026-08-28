import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

String _formatBinTypes(List<String>? types) {
  if (types == null || types.isEmpty) return 'General & Recycling Bins';
  final labels = types.map((t) {
    switch (t.toLowerCase()) {
      case 'recycling':
        return 'Recycling';
      case 'organic':
        return 'Organic Waste';
      case 'general':
        return 'General';
      default:
        return t;
    }
  }).toList();
  return '${labels.join(' & ')} Bin${labels.length > 1 ? 's' : ''}';
}

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binState = ref.watch(customerBinsProvider);
    final subState = ref.watch(customerSubscriptionProvider);

    final authState = ref.watch(authStateControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final currentUser = Supabase.instance.client.auth.currentUser;

    final displayName = user?.fullName ?? currentUser?.userMetadata?['full_name'] as String? ?? 'Customer';
    // The profiles row, not auth metadata — a picture in user_metadata rides on
    // every access token and blows the gateway's header limit.
    final photoUrl = user?.profilePictureUrl;
    final firstName = displayName.split(' ').first;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(customerBinsProvider);
            ref.invalidate(customerSubscriptionProvider);
            ref.invalidate(customerHistoryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/customer/profile'),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? (photoUrl.startsWith('data:image')
                                    ? MemoryImage(base64Decode(photoUrl.split(',').last)) as ImageProvider
                                    : NetworkImage(photoUrl))
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $firstName',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Gold Subscriber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const ThemeToggleButton(),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none_outlined,
                            size: 28,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No new notifications.'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Live tracking entry point. Renders nothing until there is
                // actually something to track, so the dashboard is unchanged
                // for customers with no booking in flight.
                const _LiveTrackingBanner(),

                // Next Pickup Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0D4), Color(0xFFFFD180)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Color(0xFFF0A500),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NEXT PICKUP Scheduled',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFC78200),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subState.when(
                                data: (sub) => sub.nextPickupDate != null
                                    ? DateFormat('EEEE, MMM d').format(sub.nextPickupDate!) +
                                        (sub.nextPickupTimeSlot != null
                                            ? ' • ${sub.nextPickupTimeSlot!.contains('08:00') ? 'Morning' : 'Afternoon'}'
                                            : '')
                                    : 'No pickup scheduled',
                                error: (_, __) => 'No pickup scheduled',
                                loading: () => 'Loading next pickup...',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E2A24),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subState.when(
                                data: (sub) => sub.nextPickupDate != null
                                    ? _formatBinTypes(sub.nextPickupBinTypes)
                                    : 'Schedule a pickup to get started',
                                error: (_, __) => 'General & Recycling Bins',
                                loading: () => 'General & Recycling Bins',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6E685E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 🛡️ Rider Delay & 3-Day Grace Period Policy Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'RIDER ON-TIME GUARANTEE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '10% Bonus Policy',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Deed Day Delay Policy: 3-day grace period for riders. If pickup fails after Day 3, get 10% off your next pickup amount automatically!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6E685E),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Outstanding Balance Banner
                subState.when(
                  data: (sub) {
                    if (sub.outstandingBalance <= 0)
                      return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withOpacity(0.3)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.shade200.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Outstanding Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GHS ${sub.outstandingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              ref
                                  .read(customerSubscriptionProvider.notifier)
                                  .payBalance();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Payment processed successfully! Balance cleared.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  error: (_, __) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                ),

                // Quick Actions Title
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: [
                    _ActionCard(
                      title: 'Request Bin',
                      tag: 'Waste',
                      gradientColors: const [Color(0xFF8EE6B0), Color(0xFF35B073)],
                      accentColor: const Color(0xFF1B7A43),
                      onTap: () => context.push('/customer/register-bin'),
                    ),
                    _ActionCard(
                      title: 'Subscriptions',
                      tag: 'Billing',
                      gradientColors: const [Color(0xFFFFD98A), Color(0xFFF3AE1D)],
                      accentColor: const Color(0xFFC78200),
                      onTap: () => context.push('/customer/subscription'),
                    ),
                    _ActionCard(
                      title: 'Request Pickup',
                      tag: 'Pickup',
                      gradientColors: const [Color(0xFF7FE9DC), Color(0xFF23B39F)],
                      accentColor: const Color(0xFF0E7A6C),
                      onTap: () => context.push('/customer/request-pickup'),
                    ),
                    _ActionCard(
                      title: 'Customer Support',
                      tag: 'Support',
                      gradientColors: const [Color(0xFFE3CDB3), Color(0xFFB79A7A)],
                      accentColor: const Color(0xFF6E5636),
                      onTap: () => context.push('/customer/support'),
                    ),
                    _ActionCard(
                      title: 'Report an Issue',
                      tag: 'Safety',
                      gradientColors: const [Color(0xFFFFAB91), Color(0xFFEF6C4D)],
                      accentColor: const Color(0xFFC1401F),
                      onTap: () => context.push('/customer/report-incident'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bins Status Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bin Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/customer/bins'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bins Status List
                binState.when(
                  data: (bins) => ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bins.length > 2 ? 2 : bins.length,
                    itemBuilder: (context, index) {
                      final bin = bins[index];
                      final isHigh = bin.fillLevelPercentage >= 0.75;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: bin.type == 'recycling'
                                            ? Colors.blue
                                            : (bin.type == 'organic'
                                                  ? Colors.green
                                                  : Colors.grey),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${bin.type[0].toUpperCase()}${bin.type.substring(1)} Waste',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(bin.fillLevelPercentage * 100).toInt()}% Full',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: isHigh ? Colors.red : Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: bin.fillLevelPercentage,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isHigh
                                        ? Colors.red
                                        : (bin.type == 'recycling'
                                              ? Colors.blue
                                              : (bin.type == 'organic'
                                                    ? Colors.green
                                                    : const Color(0xFFF0A500))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  error: (_, __) => const Text('Failed to load bins.'),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String tag;
  final List<Color> gradientColors;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.tag,
    required this.gradientColors,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -44,
              right: -24,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF20241F),
                          height: 1.15,
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

/// Dashboard banner that appears while a pickup is live and links to the
/// full-screen tracking map.
class _LiveTrackingBanner extends ConsumerWidget {
  const _LiveTrackingBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(activePickupTrackingProvider).value;
    if (tracking == null || tracking.isComplete) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final assigned = tracking.isAssigned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: assigned
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/customer/track', extra: tracking.requestId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: assigned
                        ? Colors.white.withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    assigned
                        ? Icons.local_shipping_rounded
                        : Icons.hourglass_top_rounded,
                    color: assigned ? Colors.white : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assigned
                            ? '${tracking.riderName ?? 'Your rider'} is on the way'
                            : 'Finding you a rider',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: assigned
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assigned
                            ? 'Tap to follow them live on the map'
                            : 'We will let you know the moment one accepts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: assigned
                              ? Colors.white.withValues(alpha: 0.85)
                              : theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: assigned ? Colors.white : theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
