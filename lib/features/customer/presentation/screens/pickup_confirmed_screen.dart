import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class PickupConfirmedScreen extends StatelessWidget {
  const PickupConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated check icon / status graphic
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pickup Scheduled',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your waste collection has been confirmed. Our team will arrive during your selected window.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? theme.cardTheme.color : const Color(0xFFFFF7EA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0A500).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Pickup Date',
                      value: 'Thursday, Oct 15',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: 'Time Window',
                      value: '08:00 AM - 12:00 PM',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.delete_outline,
                      label: 'Service Bins',
                      value: 'General & Recycling',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Rider Status',
                      value: 'Assigned Soon',
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Buttons
              EcoButton(
                text: 'View History',
                onPressed: () => context.go('/customer/history'),
              ),
              const SizedBox(height: 12),
              EcoButton(
                text: 'Back to Home',
                onPressed: () => context.go('/dashboard'),
                isOutlined: true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
