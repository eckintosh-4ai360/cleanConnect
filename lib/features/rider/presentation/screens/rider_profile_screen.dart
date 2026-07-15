import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderProfileScreen extends ConsumerWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(riderProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 4),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Profile',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async => ref.invalidate(riderProfileProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: profileAsync.when(
            data: (rider) => Column(
              children: [
                // ── Profile Hero ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0D4), Color(0xFFFFE0A0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(
                                rider.profilePhotoUrl ??
                                    'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200'),
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6)
                                ],
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16,
                                  color: Color(0xFFF0A500)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(rider.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Color(0xFF2E2A24))),
                      const SizedBox(height: 4),
                      Text(rider.vehicleType
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF0A500),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ProfileStat(
                              label: 'Collections',
                              value: '${rider.totalCollections}'),
                          _Divider(),
                          _ProfileStat(
                              label: 'Rating',
                              value:
                                  '${rider.rating.toStringAsFixed(1)}★'),
                          _Divider(),
                          _ProfileStat(
                              label: 'Score',
                              value:
                                  '${rider.efficiencyScore.toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatusToggle(rider: rider, ref: ref),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Personal Info ─────────────────────────────────────────
                _SectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  children: [
                    _DetailRow(label: 'Full Name', value: rider.fullName),
                    _DetailRow(label: 'Email', value: rider.email),
                    _DetailRow(
                        label: 'Phone', value: rider.phoneNumber),
                    _DetailRow(
                        label: 'Rider ID', value: rider.id.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Vehicle & License ─────────────────────────────────────
                _SectionCard(
                  title: 'Vehicle & License',
                  icon: Icons.directions_car_outlined,
                  isDark: isDark,
                  children: [
                    _DetailRow(
                        label: 'Vehicle Type',
                        value: rider.vehicleType
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((w) =>
                                '${w[0].toUpperCase()}${w.substring(1)}')
                            .join(' ')),
                    _DetailRow(
                        label: 'License Number',
                        value: rider.licenseNumber),
                    _DetailRow(
                        label: 'National ID',
                        value: rider.nationalIdNumber),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Earnings ─────────────────────────────────────────────
                _SectionCard(
                  title: 'Earnings',
                  icon: Icons.payments_outlined,
                  isDark: isDark,
                  children: [
                    _DetailRow(
                        label: 'This Month',
                        value:
                            '\$${rider.earningsThisMonth.toStringAsFixed(2)}'),
                    _DetailRow(
                        label: 'Total Weight',
                        value:
                            '${(rider.totalWeightKg / 1000).toStringAsFixed(1)} tons'),
                    _DetailRow(
                        label: 'Avg per Trip',
                        value: rider.totalCollections > 0
                            ? '\$${(rider.earningsThisMonth / rider.totalCollections * 30).toStringAsFixed(2)}'
                            : '\$0.00'),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Settings / Actions ─────────────────────────────────────
                _SectionCard(
                  title: 'Settings',
                  icon: Icons.settings_outlined,
                  isDark: isDark,
                  children: [
                    _ActionRow(
                      label: 'Notifications',
                      icon: Icons.notifications_outlined,
                      onTap: () => context.push('/rider/notifications'),
                    ),
                    _ActionRow(
                      label: 'Help & Support',
                      icon: Icons.headset_mic_outlined,
                      onTap: () {},
                    ),
                    _ActionRow(
                      label: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Logout ─────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.go('/login'),
                  ),
                ),
              ],
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Failed to load profile.')),
          ),
        ),
      ),
    );
  }
}

// ── Sub Widgets ───────────────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Color(0xFF2E2A24))),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E685E))),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 30, color: Colors.white.withOpacity(0.6));
  }
}

class _StatusToggle extends StatelessWidget {
  final dynamic rider;
  final WidgetRef ref;
  const _StatusToggle({required this.rider, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isOnline = rider.status == 'active' || rider.status == 'on_route';
    return GestureDetector(
      onTap: () {
        ref.read(riderProfileProvider.notifier).updateStatus(
              isOnline ? 'offline' : 'active',
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline
                ? 'You are now offline.'
                : 'You are now active!'),
            backgroundColor: isOnline ? Colors.grey : Colors.green,
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isOnline
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline
                ? Colors.green.shade300
                : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isOnline ? 'Online – Tap to go offline' : 'Offline – Tap to go online',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? Colors.green : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(icon,
                    color: const Color(0xFFF0A500), size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14))),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
