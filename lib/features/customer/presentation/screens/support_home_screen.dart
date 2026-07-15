import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/customer_providers.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class SupportHomeScreen extends HookConsumerWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchQuery = useState('');

    useEffect(() {
      void listener() {
        searchQuery.value = searchController.text.trim().toLowerCase();
      }
      searchController.addListener(listener);
      return () => searchController.removeListener(listener);
    }, []);

    final faqs = [
      _FaqData(
        question: 'How do I change my pickup schedule?',
        answer: 'You can change your collection schedule by navigating to Bins -> Select Bin -> Edit Schedule, or by updating your active subscription plan.',
        category: 'pickup',
      ),
      _FaqData(
        question: 'What are the available bin sizes?',
        answer: 'We offer 120L (Small), 240L (Standard/Large), and 360L (Extra Large) bins for General, Recycling, and Organic waste.',
        category: 'bins',
      ),
      _FaqData(
        question: 'How do I pay my outstanding balance?',
        answer: 'Outstanding balances are visible on your Dashboard. You can pay instantly using Credit/Debit Card or Mobile Money.',
        category: 'payments',
      ),
      _FaqData(
        question: 'What items can be recycled?',
        answer: 'Plastics (PET, HDPE), paper, clean cardboard, glass bottles, and aluminum cans are accepted in the Recycling bin.',
        category: 'recycling',
      ),
    ];

    // Filter FAQs
    final filteredFaqs = faqs.where((faq) {
      if (searchQuery.value.isEmpty) return true;
      return faq.question.toLowerCase().contains(searchQuery.value) ||
          faq.answer.toLowerCase().contains(searchQuery.value);
    }).toList();

    // Problem reporting details sheet
    void reportProblem(String categoryName) {
      final problemNoteController = TextEditingController();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report: $categoryName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please provide details about the issue. Our support team will review this shortly.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: problemNoteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter description of the problem...',
                  ),
                ),
                const SizedBox(height: 24),
                EcoButton(
                  text: 'Submit Report',
                  onPressed: () {
                    if (problemNoteController.text.trim().isNotEmpty) {
                      ref.read(customerHistoryProvider.notifier).submitProblem(
                            category: categoryName,
                            description: problemNoteController.text.trim(),
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report submitted successfully! Ticket added to history.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    }

    // Call Us action
    Future<void> makePhoneCall() async {
      final Uri uri = Uri(scheme: 'tel', path: '+18001234567');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not trigger phone application.')),
        );
      }
    }

    // Email Support action
    Future<void> sendEmail() async {
      final Uri uri = Uri(
        scheme: 'mailto',
        path: 'support@ecowaste.com',
        queryParameters: {
          'subject': 'EcoWaste Customer Support Request',
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not trigger email application.')),
        );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Support', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search for help...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.value.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => searchController.clear())
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // FAQs expandable list
              if (filteredFaqs.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No FAQs match your search query.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ] else ...[
                ...filteredFaqs.map((faq) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Text(faq.answer, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.grey)),
                          ),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 24),
              const Text('Report a Problem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // Missed collection, damaged bin options
              _ReportTile(
                title: 'Missed Collection',
                subtitle: 'Rider did not collect scheduled waste',
                onTap: () => reportProblem('Missed Collection'),
              ),
              _ReportTile(
                title: 'Damaged Bin',
                subtitle: 'Request bin replacement or repairs',
                onTap: () => reportProblem('Damaged Bin'),
              ),
              _ReportTile(
                title: 'Request Extra Pickup',
                subtitle: 'Request emergency overflow collection',
                onTap: () => reportProblem('Extra Pickup Request'),
              ),

              const SizedBox(height: 32),
              const Text('Contact Support Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              // Contact cards (Call Us & Email)
              _ContactCard(
                title: 'Call Us',
                subtitle: 'Available Mon-Fri, 8am - 6pm',
                detail: '+1 (800) 123-4567',
                icon: Icons.phone_outlined,
                onTap: makePhoneCall,
              ),
              const SizedBox(height: 12),
              _ContactCard(
                title: 'Email Support',
                subtitle: 'We respond within 24 hours',
                detail: 'support@ecowaste.com',
                icon: Icons.mail_outline,
                onTap: sendEmail,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqData {
  final String question;
  final String answer;
  final String category;

  _FaqData({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _ContactCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.cardTheme.color : const Color(0xFFFFF7EA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0A500).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0D4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFC78200)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
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
