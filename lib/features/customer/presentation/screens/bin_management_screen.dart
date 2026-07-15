import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/customer_entities.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';

class BinManagementScreen extends ConsumerWidget {
  const BinManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binState = ref.watch(customerBinsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: const Text('My Bins', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: binState.when(
          data: (bins) {
            if (bins.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline, size: 72, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No Bins Registered', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Register a bin to start tracking your waste.'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/customer/register-bin'),
                      icon: const Icon(Icons.add),
                      label: const Text('Register New Bin'),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: bins.length,
                      itemBuilder: (context, index) {
                        final bin = bins[index];
                        final isHigh = bin.fillLevelPercentage >= 0.75;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? theme.cardTheme.color : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            ),
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
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: bin.type == 'recycling'
                                              ? Colors.blue.shade50
                                              : (bin.type == 'organic' ? Colors.green.shade50 : Colors.grey.shade100),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.delete,
                                          color: bin.type == 'recycling'
                                              ? Colors.blue
                                              : (bin.type == 'organic' ? Colors.green : Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${bin.type[0].toUpperCase()}${bin.type.substring(1)} Waste',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Capacity: ${bin.size}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // QR Code action icon
                                  IconButton(
                                    icon: const Icon(Icons.qr_code, color: Color(0xFFF0A500)),
                                    onPressed: () {
                                      _showQrDialog(context, bin);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Status: ${isHigh ? "Action Needed" : "Active"}',
                                    style: TextStyle(
                                      color: isHigh ? Colors.red : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                      '${(bin.fillLevelPercentage * 100).toInt()}% Full',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isHigh ? Colors.red : theme.colorScheme.primary,
                                        fontSize: 14,
                                      ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: bin.fillLevelPercentage,
                                  minHeight: 10,
                                  backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isHigh
                                        ? Colors.red
                                        : (bin.type == 'recycling'
                                            ? Colors.blue
                                            : (bin.type == 'organic' ? Colors.green : const Color(0xFFF0A500))),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Serial Number', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        bin.serialNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Schedule Frequency', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        bin.scheduleFrequency ?? 'Weekly',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/customer/register-bin'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Register New Bin'),
                    ),
                  ),
                ],
              ),
            );
          },
          error: (_, __) => const Center(child: Text('Error loading bins.')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context, BinEntity bin) {
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
                    Text(
                      'Bin QR Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Simulated QR Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Image.network(
                    'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${bin.serialNumber}',
                    width: 180,
                    height: 180,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 180,
                        height: 180,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.qr_code, size: 64, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  bin.serialNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waste Type: ${bin.type.toUpperCase()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Use this code for collection confirmation and issue reporting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
