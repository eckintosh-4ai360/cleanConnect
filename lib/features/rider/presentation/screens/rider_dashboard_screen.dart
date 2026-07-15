import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderDashboardScreen extends ConsumerWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(riderProfileProvider);
    final routeAsync = ref.watch(riderActiveRouteProvider);
    final notifAsync = ref.watch(riderNotificationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(riderProfileProvider);
            ref.invalidate(riderActiveRouteProvider);
            ref.invalidate(riderNotificationsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    profileAsync.when(
                      data: (rider) => Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(
                                rider.profilePhotoUrl ??
                                    'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200'),
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${rider.fullName.split(' ').first}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900),
                              ),
                              _StatusBadge(status: rider.status),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                          height: 48,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2))),
                      error: (_, _) => const Text('EcoWaste Rider'),
                    ),
                    Row(
                      children: [
                        const ThemeToggleButton(),
                        const SizedBox(width: 8),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.notifications_none_outlined,
                                  size: 28),
                              onPressed: () =>
                                  context.push('/rider/notifications'),
                            ),
                            notifAsync.when(
                              data: (notifs) {
                                final unread =
                                    notifs.where((n) => !n.isRead).length;
                                if (unread == 0) return const SizedBox.shrink();
                                return Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$unread',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Active Route Card ────────────────────────────────────
                routeAsync.when(
                  data: (route) {
                    if (route == null) {
                      return _NoRouteCard(theme: theme);
                    }
                    return _ActiveRouteCard(route: route, theme: theme);
                  },
                  loading: () => const Center(
                      child:
                          Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator())),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // ── Quick Stats ──────────────────────────────────────────
                Text("Today's Stats",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                profileAsync.when(
                  data: (rider) => Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Collections',
                          value: '5',
                          icon: Icons.recycling,
                          color: const Color(0xFFE8F5E9),
                          iconColor: Colors.green,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Weight',
                          value: '72.5 kg',
                          icon: Icons.scale_outlined,
                          color: const Color(0xFFE3F2FD),
                          iconColor: Colors.blue,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Earnings',
                          value: '\$41.20',
                          icon: Icons.payments_outlined,
                          color: const Color(0xFFFFF8E1),
                          iconColor: Colors.amber.shade800,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(height: 80),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // ── Quick Actions ────────────────────────────────────────
                Text('Quick Actions',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _QuickActionCard(
                      title: 'Scan Collection',
                      subtitle: 'QR code scan',
                      icon: Icons.qr_code_scanner,
                      color: const Color(0xFFF3E5F5),
                      iconColor: Colors.purple,
                      isDark: isDark,
                      onTap: () => context.push('/rider/collection'),
                    ),
                    _QuickActionCard(
                      title: 'View Route',
                      subtitle: 'Active stops',
                      icon: Icons.map_outlined,
                      color: const Color(0xFFE8F5E9),
                      iconColor: Colors.green,
                      isDark: isDark,
                      onTap: () => context.push('/rider/route'),
                    ),
                    _QuickActionCard(
                      title: 'Performance',
                      subtitle: 'My stats',
                      icon: Icons.bar_chart,
                      color: const Color(0xFFE3F2FD),
                      iconColor: Colors.blue,
                      isDark: isDark,
                      onTap: () => context.push('/rider/performance'),
                    ),
                    _QuickActionCard(
                      title: 'Notifications',
                      subtitle: 'Messages & alerts',
                      icon: Icons.notifications_outlined,
                      color: const Color(0xFFFFF8E1),
                      iconColor: Colors.amber.shade800,
                      isDark: isDark,
                      onTap: () => context.push('/rider/notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Recent Collections ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Collections',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push('/rider/collection'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ref.watch(riderCollectionHistoryProvider).when(
                  data: (logs) {
                    final recent = logs.take(3).toList();
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recent.length,
                      itemBuilder: (context, index) {
                        final log = recent[index];
                        return _CollectionLogTile(log: log, theme: theme);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Text('Failed to load collections.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'active':
      case 'on_route':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String get _label {
    switch (status) {
      case 'active':
        return 'Active';
      case 'on_route':
        return 'On Route';
      case 'offline':
        return 'Offline';
      case 'pending_approval':
        return 'Pending Approval';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          _label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: _color),
        ),
      ],
    );
  }
}

class _NoRouteCard extends StatelessWidget {
  final ThemeData theme;
  const _NoRouteCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.route_outlined,
                color: Colors.grey.shade500, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Active Route',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Your next route will appear here once assigned.',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRouteCard extends StatelessWidget {
  final dynamic route;
  final ThemeData theme;
  const _ActiveRouteCard({required this.route, required this.theme});

  @override
  Widget build(BuildContext context) {
    final progress = route.completedStops / route.totalStops;
    return GestureDetector(
      onTap: () => context.push('/rider/route'),
      child: Container(
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
              color: const Color(0xFFF0A500).withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          color: Color(0xFFF0A500), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACTIVE ROUTE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFC78200),
                                letterSpacing: 1.0)),
                        Text(route.routeName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E2A24))),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${route.zone}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6E685E))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RouteStatChip(
                    label: '${route.completedStops}/${route.totalStops}',
                    sublabel: 'Stops'),
                _RouteStatChip(
                    label: '${route.totalDistanceKm.toStringAsFixed(1)} km',
                    sublabel: 'Total'),
                _RouteStatChip(
                    label: DateFormat('h:mm a')
                        .format(route.estimatedEndTime ?? DateTime.now()),
                    sublabel: 'Est. End'),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.6),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF0A500)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toInt()}% complete',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6E685E),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  const _RouteStatChip({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF2E2A24))),
        Text(sublabel,
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF6E685E))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.cardTheme.color : color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionLogTile extends StatelessWidget {
  final dynamic log;
  final ThemeData theme;
  const _CollectionLogTile({required this.log, required this.theme});

  Color _binColor(String type) {
    switch (type) {
      case 'recycling':
        return Colors.blue;
      case 'organic':
        return Colors.green;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'problem':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _binColor(log.binType).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, color: _binColor(log.binType), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(log.address,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${log.weightKg} kg',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(log.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.status == 'pending_review' ? 'Review' : log.status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(log.status)),
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
