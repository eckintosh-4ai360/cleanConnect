import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/customer_entities.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';

class ServiceHistoryScreen extends HookConsumerWidget {
  const ServiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(customerHistoryProvider);
    final selectedTab = useState('All'); // 'All', 'Collections', 'Payments', 'Support'
    final searchController = useTextEditingController();
    final searchQuery = useState('');

    useEffect(() {
      void listener() {
        searchQuery.value = searchController.text.trim();
      }
      searchController.addListener(listener);
      return () => searchController.removeListener(listener);
    }, []);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search history...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            // Custom Horizontal Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['All', 'Collections', 'Payments', 'Support'].map((tab) {
                    final isSelected = selectedTab.value == tab;
                    return GestureDetector(
                      onTap: () => selectedTab.value = tab,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // History list
            Expanded(
              child: historyState.when(
                data: (records) {
                  // Filter by tab
                  var filtered = records;
                  if (selectedTab.value != 'All') {
                    filtered = filtered.where((r) => r.type == selectedTab.value.toLowerCase().replaceAll('s', '')).toList();
                  }

                  // Filter by search query
                  if (searchQuery.value.isNotEmpty) {
                    filtered = filtered
                        .where((r) => r.title.toLowerCase().contains(searchQuery.value.toLowerCase()))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No records found', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          const Text('Make requests or payments to populate your history.'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      final formattedDate = DateFormat('MMM dd, yyyy').format(record.date);
                      final isCompleted = record.status == 'completed';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            if (record.type == 'collection') {
                              context.push('/customer/service-record?id=${record.id}');
                            } else {
                              _showRecordReceipt(context, record);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: record.type == 'collection'
                                ? Colors.green.shade50
                                : (record.type == 'payment' ? Colors.orange.shade50 : Colors.red.shade50),
                            child: Icon(
                              record.type == 'collection'
                                  ? Icons.delete_outline
                                  : (record.type == 'payment' ? Icons.payment : Icons.support_agent),
                              color: record.type == 'collection'
                                  ? Colors.green
                                  : (record.type == 'payment' ? Colors.orange : Colors.red),
                            ),
                          ),
                          title: Text(
                            record.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '$formattedDate • ${record.status.toUpperCase()}',
                            style: TextStyle(
                              color: isCompleted ? Colors.grey : Colors.orange,
                              fontSize: 11,
                              fontWeight: isCompleted ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (record.type == 'payment') ...[
                                Text(
                                  '\$${record.amountPaid.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ] else if (record.type == 'collection') ...[
                                Text(
                                  record.weightKg != null ? '${record.weightKg} kg' : '0.0 kg',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ] else ...[
                                const Icon(Icons.chevron_right),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                error: (_, __) => const Center(child: Text('Error loading history.')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordReceipt(BuildContext context, ServiceRecordEntity record) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Service Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 24),
                // Lock Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('COMPLETED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(height: 16),
                Text(
                  '\$${record.amountPaid.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                _ReceiptRow(label: 'Receipt Number', value: record.receiptNumber ?? 'REC-2026-MOCK'),
                const SizedBox(height: 8),
                _ReceiptRow(label: 'Payment Date', value: DateFormat('MMM dd, yyyy').format(record.date)),
                const SizedBox(height: 8),
                const _ReceiptRow(label: 'Service Charge', value: '\$12.00'),
                const SizedBox(height: 8),
                const _ReceiptRow(label: 'Tax', value: '\$3.00'),
                const SizedBox(height: 8),
                const _ReceiptRow(label: 'Payment Method', style: TextStyle(fontWeight: FontWeight.bold), value: 'Mobile Money (Ending 4241)'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading invoice receipt...'), backgroundColor: Colors.green),
                    );
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: style ?? const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
