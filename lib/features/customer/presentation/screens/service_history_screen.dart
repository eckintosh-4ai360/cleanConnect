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
    final pickupsState = ref.watch(customerPickupRequestsProvider);
    final selectedTab = useState(
      'All',
    ); // 'All', 'Pickups', 'Collections', 'Payments', 'Support'
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
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
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
                  children: ['All', 'Pickups', 'Collections', 'Payments', 'Support'].map((
                    tab,
                  ) {
                    final isSelected = selectedTab.value == tab;
                    return GestureDetector(
                      onTap: () => selectedTab.value = tab,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade200,
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
              child: selectedTab.value == 'Pickups'
                  ? _PickupHistoryList(
                      pickupsState: pickupsState,
                      searchQuery: searchQuery.value,
                    )
                  : historyState.when(
                data: (records) {
                  // Filter by tab
                  var filtered = records;
                  if (selectedTab.value != 'All') {
                    filtered = filtered
                        .where(
                          (r) =>
                              r.type ==
                              selectedTab.value.toLowerCase().replaceAll(
                                's',
                                '',
                              ),
                        )
                        .toList();
                  }

                  // Filter by search query
                  if (searchQuery.value.isNotEmpty) {
                    filtered = filtered
                        .where(
                          (r) => r.title.toLowerCase().contains(
                            searchQuery.value.toLowerCase(),
                          ),
                        )
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history_toggle_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No records found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Make requests or payments to populate your history.',
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 8,
                      bottom: 100,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      final formattedDate = DateFormat(
                        'MMM dd, yyyy',
                      ).format(record.date);
                      final isCompleted = record.status == 'completed';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            if (record.type == 'collection') {
                              context.push(
                                '/customer/service-record?id=${record.id}',
                              );
                            } else {
                              _showRecordReceipt(context, record);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: record.type == 'collection'
                                ? Colors.green.shade50
                                : (record.type == 'payment'
                                      ? Colors.orange.shade50
                                      : Colors.red.shade50),
                            child: Icon(
                              record.type == 'collection'
                                  ? Icons.delete_outline
                                  : (record.type == 'payment'
                                        ? Icons.payment
                                        : Icons.support_agent),
                              color: record.type == 'collection'
                                  ? Colors.green
                                  : (record.type == 'payment'
                                        ? Colors.orange
                                        : Colors.red),
                            ),
                          ),
                          title: Text(
                            record.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$formattedDate • ${record.status.toUpperCase()}',
                            style: TextStyle(
                              color: isCompleted ? Colors.grey : Colors.orange,
                              fontSize: 11,
                              fontWeight: isCompleted
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (record.type == 'payment') ...[
                                Text(
                                  'GHS ${record.amountPaid.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ] else if (record.type == 'collection') ...[
                                Text(
                                  record.weightKg != null
                                      ? '${record.weightKg} kg'
                                      : '0.0 kg',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
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
                error: (_, _) =>
                    const Center(child: Text('Error loading history.')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordReceipt(BuildContext context, ServiceRecordEntity record) {
    final serviceCharge = record.amountPaid;
    const tax = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Lock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GHS ${record.amountPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _ReceiptRow(
                    label: 'Receipt Number',
                    value: record.receiptNumber ?? 'REC-2026-MOCK',
                  ),
                  const SizedBox(height: 8),
                  _ReceiptRow(
                    label: 'Payment Date',
                    value: DateFormat('MMM dd, yyyy').format(record.date),
                  ),
                  const SizedBox(height: 8),
                  _ReceiptRow(
                    label: 'Service Charge',
                    value: 'GHS ${serviceCharge.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _ReceiptRow(
                    label: 'Tax',
                    value: 'GHS ${tax.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _ReceiptRow(
                    label: 'Payment Method',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    value: record.paymentMethod ?? 'Mobile Money',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Downloading invoice receipt...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pickup-request history for the 'Pickups' tab. Separate from the
/// service_history-backed list above -- pickup_requests is a structurally
/// different table/entity, and mixing the two into one merged feed would
/// need a common summary shape neither side actually has.
class _PickupHistoryList extends StatelessWidget {
  final AsyncValue<List<PickupRequestEntity>> pickupsState;
  final String searchQuery;

  const _PickupHistoryList({required this.pickupsState, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return pickupsState.when(
      data: (requests) {
        var filtered = requests;
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where(
                (r) =>
                    r.binTypes.join(' ').toLowerCase().contains(q) ||
                    r.location.toLowerCase().contains(q),
              )
              .toList();
        }

        // Most recent first -- watchPickupRequests doesn't guarantee order.
        filtered = [...filtered]..sort((a, b) => b.date.compareTo(a.date));

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text('No pickups found', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Requests you schedule will show up here.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 100,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _PickupCard(request: filtered[index]),
        );
      },
      error: (_, _) => const Center(child: Text('Error loading pickups.')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PickupCard extends HookConsumerWidget {
  final PickupRequestEntity request;

  const _PickupCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelling = useState(false);
    final formattedDate = DateFormat('MMM dd, yyyy').format(request.date);
    final statusColor = _statusColor(request.status);
    final binsLabel = request.binTypes
        .map((t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1))
        .join(', ');

    Future<void> confirmCancel() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel this pickup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${binsLabel.isEmpty ? 'This' : binsLabel} pickup on $formattedDate '
                '(${request.timeSlot}) will be cancelled.',
              ),
              if (request.amountPaid > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'GHS ${request.amountPaid.toStringAsFixed(2)} already paid for this '
                  'request will not be automatically refunded.',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Pickup'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Pickup'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      isCancelling.value = true;
      try {
        await ref.read(customerPickupRequestsProvider.notifier).cancelPickup(request.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pickup cancelled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not cancel: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        isCancelling.value = false;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(_statusIcon(request.status), color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        binsLabel.isEmpty ? 'Pickup' : '$binsLabel Pickup',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$formattedDate • ${request.timeSlot}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            if (request.isCancellable) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isCancelling.value ? null : confirmCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: isCancelling.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(isCancelling.value ? 'Cancelling...' : 'Cancel Pickup'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default: // accepted, assigned, confirmed
        return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.hourglass_top_outlined;
      default: // accepted, assigned, confirmed
        return Icons.local_shipping_outlined;
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _ReceiptRow({required this.label, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style:
                style ??
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
