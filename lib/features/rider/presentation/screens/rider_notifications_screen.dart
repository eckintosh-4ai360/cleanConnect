import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/rider_providers.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderNotificationsScreen extends ConsumerWidget {
  const RiderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(riderNotificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Notifications',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          notifAsync.when(
            data: (notifs) {
              final hasUnread = notifs.any((n) => !n.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    ref.read(riderNotificationsProvider.notifier).markAllRead(),
                child: const Text('Mark all read',
                    style: TextStyle(fontSize: 12)),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No Notifications',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }
          final unread = notifications.where((n) => !n.isRead).toList();
          final read = notifications.where((n) => n.isRead).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (unread.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('New',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
                ...unread.map((n) => _NotificationCard(
                    notif: n,
                    onTap: () =>
                        ref.read(riderNotificationsProvider.notifier).markRead(n.id))),
                const SizedBox(height: 16),
              ],
              if (read.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Earlier',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
                ...read.map((n) => _NotificationCard(notif: n, onTap: null)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Failed to load notifications.')),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final dynamic notif;
  final VoidCallback? onTap;
  const _NotificationCard({required this.notif, required this.onTap});

  IconData get _icon {
    switch (notif.type) {
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'new_route':
        return Icons.route;
      case 'payment':
        return Icons.payments_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (notif.type) {
      case 'alert':
        return Colors.red;
      case 'new_route':
        return const Color(0xFFF0A500);
      case 'payment':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = !notif.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark
                  ? _color.withOpacity(0.1)
                  : _color.withOpacity(0.06))
              : (isDark ? theme.cardTheme.color : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? _color.withOpacity(0.3)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.w900
                                    : FontWeight.bold,
                                fontSize: 14)),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.message,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4)),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(notif.receivedAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}
