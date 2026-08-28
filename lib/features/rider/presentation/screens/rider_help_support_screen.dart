import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderHelpSupportScreen extends HookWidget {
  const RiderHelpSupportScreen({super.key});

  static const _supportPhone = '+233 24 881 4260';
  static const _supportEmail = 'support@cleanconnect.com';

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final searchQuery = useState('');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const faqs = [
      _RiderFaq(
        'How do I start a collection?',
        'Open an assigned pickup, travel to the location, then scan the bin QR code to begin the collection.',
      ),
      _RiderFaq(
        'What should I do if a bin cannot be collected?',
        'Open the collection and record the issue before you leave the location. Add a clear note so the team can follow up.',
      ),
      _RiderFaq(
        'Why is my route different today?',
        'Routes are optimized based on assigned pickups, priority requests, and current collection status.',
      ),
      _RiderFaq(
        'When are my earnings updated?',
        'Completed collections are reflected in your performance and earnings after they have been verified.',
      ),
    ];
    final filteredFaqs = faqs
        .where((faq) => faq.matches(searchQuery.value))
        .toList(growable: false);

    Future<void> openSupportUri(Uri uri, String failureMessage) async {
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failureMessage)));
        }
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Help & Support',
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
            _SupportHero(isDark: isDark),
            const SizedBox(height: 24),
            TextField(
              controller: searchController,
              onChanged: (value) =>
                  searchQuery.value = value.trim().toLowerCase(),
              decoration: InputDecoration(
                hintText: 'Search rider help',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.value.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: searchController.clear,
                      ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Frequently asked questions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No help topics match your search.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ...filteredFaqs.map((faq) => _FaqTile(faq: faq, isDark: isDark)),
            const SizedBox(height: 28),
            Text(
              'Contact support',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.phone_outlined,
              title: 'Call support',
              subtitle: 'Mon–Fri, 8:00 AM–6:00 PM',
              detail: _supportPhone,
              isDark: isDark,
              onTap: () => openSupportUri(
                Uri(scheme: 'tel', path: _supportPhone.replaceAll(' ', '')),
                'Could not open the phone app.',
              ),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.mail_outline_rounded,
              title: 'Email support',
              subtitle: 'We usually reply within 24 hours',
              detail: _supportEmail,
              isDark: isDark,
              onTap: () => openSupportUri(
                Uri(
                  scheme: 'mailto',
                  path: _supportEmail,
                  queryParameters: const {
                    'subject': 'CleanConnect Rider Support Request',
                  },
                ),
                'Could not open the email app.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF29241B) : const Color(0xFFFFF0D4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF0A500),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headset_mic_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Find quick answers or contact the rider support team.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.isDark});

  final _RiderFaq faq;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFF1ECE4),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: const Color(0xFFF0A500),
        collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        title: Text(
          faq.question,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq.answer,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF0A500).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0D4),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFC78200)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFFF0A500),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderFaq {
  const _RiderFaq(this.question, this.answer);

  final String question;
  final String answer;

  bool matches(String query) =>
      query.isEmpty ||
      question.toLowerCase().contains(query) ||
      answer.toLowerCase().contains(query);
}
