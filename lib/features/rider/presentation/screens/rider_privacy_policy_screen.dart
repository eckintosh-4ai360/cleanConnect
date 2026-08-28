import 'package:flutter/material.dart';

class RiderPrivacyPolicyScreen extends StatelessWidget {
  const RiderPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF29241B)
                    : const Color(0xFFFFF0D4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFFF0A500),
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your data, handled with care',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Last updated: August 2026',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _PolicySection(
              title: 'Overview',
              body:
                  'CleanConnect uses rider information to assign collections, support safe service delivery, and improve the rider experience. This policy explains the information we collect and how it is used.',
            ),
            const _PolicySection(
              title: 'Information we collect',
              body:
                  'This may include your profile and contact details, vehicle information, collection activity, service records, device information, and location data while you use rider tools that need it.',
            ),
            const _PolicySection(
              title: 'How we use your information',
              body:
                  'We use this information to manage rider accounts, plan and verify collections, provide navigation and support, calculate performance and earnings, maintain security, and meet legal obligations.',
            ),
            const _PolicySection(
              title: 'Location information',
              body:
                  'Location may be used while you are on duty to show relevant pickups, help with routes, and confirm collection activity. You can manage location permission in your device settings, although some rider features may then be unavailable.',
            ),
            const _PolicySection(
              title: 'Sharing and protection',
              body:
                  'We only share information with authorized service partners and team members when needed to provide the service, process payments, comply with the law, or protect our users and platform. We apply appropriate safeguards to protect your information.',
            ),
            const _PolicySection(
              title: 'Your choices',
              body:
                  'You can request access to or correction of your account information, and ask questions about this policy, by contacting CleanConnect Support.',
            ),
            const SizedBox(height: 8),
            Text(
              'For privacy questions, contact support@cleanconnect.com.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFF0A500),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}
