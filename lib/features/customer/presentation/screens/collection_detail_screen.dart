import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/customer_entities.dart';
import '../providers/customer_providers.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String recordId;

  const CollectionDetailScreen({
    super.key,
    required this.recordId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(customerHistoryProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Service Record', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: historyState.when(
          data: (records) {
            final record = records.firstWhere(
              (r) => r.id == recordId,
              orElse: () => records.first,
            );

            final formattedDate = DateFormat('EEEE, MMM dd, yyyy').format(record.date);
            final composition = record.compositionPercentages ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Status Completed Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Collection Weight summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardTheme.color : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Collection Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        _SummaryRowDetail(label: 'Date', value: formattedDate),
                        const Divider(height: 24),
                        const _SummaryRowDetail(label: 'Time', value: '09:20 AM'),
                        const Divider(height: 24),
                        _SummaryRowDetail(
                          label: 'Total Weight',
                          value: record.weightKg != null ? '${record.weightKg} kg' : '0.0 kg',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sustainability Impact Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardTheme.color : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sustainability Impact',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${record.co2OffsetKg ?? 0.0} kg',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.green),
                              ),
                              const Text(
                                'CO2 equivalent saved through recycling',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Waste Composition breakdown
                  if (composition.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? theme.cardTheme.color : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waste Composition',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ...composition.entries.map((entry) {
                            final type = entry.key;
                            final percent = entry.value;
                            Color progressColor = Colors.grey;
                            if (type == 'Plastics') {
                              progressColor = Colors.orange;
                            } else if (type == 'Paper') {
                              progressColor = Colors.blue;
                            } else if (type == 'Glass') {
                              progressColor = Colors.teal;
                            } else if (type == 'Organic') {
                              progressColor = Colors.green;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${percent.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: percent / 100,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  EcoButton(
                    text: 'Back to History',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 12),
                  EcoButton(
                    text: 'View Receipt',
                    onPressed: () {
                      _showReceipt(context, record);
                    },
                    isOutlined: true,
                  ),
                ],
              ),
            );
          },
          error: (_, __) => const Center(child: Text('Error loading record details.')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, ServiceRecordEntity record) {
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
                _SummaryRowDetail(label: 'Receipt Number', value: record.receiptNumber ?? 'REC-2026-MOCK'),
                const SizedBox(height: 8),
                _SummaryRowDetail(label: 'Collection Date', value: DateFormat('MMM dd, yyyy').format(record.date)),
                const SizedBox(height: 8),
                const _SummaryRowDetail(label: 'Service Charge', value: '\$12.00'),
                const SizedBox(height: 8),
                const _SummaryRowDetail(label: 'Weight Tax', value: '\$3.00'),
                const SizedBox(height: 8),
                const _SummaryRowDetail(
                  label: 'Payment Method',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  value: 'Card (Visa ending 4240)',
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading receipt...'), backgroundColor: Colors.green),
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

class _SummaryRowDetail extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _SummaryRowDetail({
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
