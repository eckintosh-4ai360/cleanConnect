import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/customer_entities.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_nav_bar.dart';
import '../widgets/bins_map_view.dart';

const _kScheduleDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

enum _BinsViewMode { list, map }

class BinManagementScreen extends HookConsumerWidget {
  const BinManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binState = ref.watch(customerBinsProvider);
    final viewMode = useState(_BinsViewMode.list);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'My Bins',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: viewMode.value == _BinsViewMode.list
                ? 'Show on map'
                : 'Show as list',
            icon: Icon(
              viewMode.value == _BinsViewMode.list
                  ? Icons.map_outlined
                  : Icons.view_list_outlined,
            ),
            onPressed: () {
              viewMode.value = viewMode.value == _BinsViewMode.list
                  ? _BinsViewMode.map
                  : _BinsViewMode.list;
            },
          ),
        ],
      ),
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: viewMode.value == _BinsViewMode.map
            ? binState.when(
                data: (bins) => BinsMapView(bins: bins),
                error: (_, __) => const Center(child: Text('Error loading bins.')),
                loading: () => const Center(child: CircularProgressIndicator()),
              )
            : binState.when(
          data: (bins) {
            if (bins.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 72,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Bins Registered',
                      style: theme.textTheme.titleMedium,
                    ),
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
                            color: isDark
                                ? theme.cardTheme.color
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: bin.type == 'recycling'
                                                ? Colors.blue.shade50
                                                : (bin.type == 'organic'
                                                      ? Colors.green.shade50
                                                      : Colors.grey.shade100),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            color: bin.type == 'recycling'
                                                ? Colors.blue
                                                : (bin.type == 'organic'
                                                      ? Colors.green
                                                      : Colors.grey.shade600),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${bin.type[0].toUpperCase()}${bin.type.substring(1)} Waste',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                'Capacity: ${bin.size}',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // QR Code action icon
                                  IconButton(
                                    icon: const Icon(
                                      Icons.qr_code,
                                      color: Color(0xFFF0A500),
                                    ),
                                    onPressed: () {
                                      _showQrDialog(context, bin);
                                    },
                                  ),
                                  if (bin.isPersonal)
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditBinDialog(context, ref, bin);
                                        } else if (value == 'delete') {
                                          _showDeleteBinDialog(context, ref, bin);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit Schedule'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete Bin'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Status: ${isHigh ? "Action Needed" : "Active"}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isHigh
                                            ? Colors.red
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(bin.fillLevelPercentage * 100).toInt()}% Full',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: isHigh
                                          ? Colors.red
                                          : theme.colorScheme.primary,
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
                                  backgroundColor: isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isHigh
                                        ? Colors.red
                                        : (bin.type == 'recycling'
                                              ? Colors.blue
                                              : (bin.type == 'organic'
                                                    ? Colors.green
                                                    : const Color(0xFFF0A500))),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Serial Number',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bin.serialNumber,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Schedule Frequency',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bin.scheduleFrequency ?? 'Weekly',
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                        child: const Icon(
                          Icons.qr_code,
                          size: 64,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  bin.serialNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
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

  void _showEditBinDialog(BuildContext context, WidgetRef ref, BinEntity bin) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String frequency = bin.scheduleFrequency ?? 'Weekly';
        String day = bin.pickupDays?.isNotEmpty == true
            ? bin.pickupDays!.first
            : 'Monday';
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Edit Collection Schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frequency', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: frequency,
                    items: const ['Weekly', 'Bi-weekly', 'Monthly']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) setState(() => frequency = val);
                          },
                  ),
                  const SizedBox(height: 12),
                  const Text('Pickup Day', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: day,
                    items: _kScheduleDays
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) setState(() => day = val);
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          try {
                            await ref.read(customerBinsProvider.notifier).updateBin(
                                  binId: bin.id,
                                  frequency: frequency,
                                  pickupDays: [day],
                                );
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update bin: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteBinDialog(BuildContext context, WidgetRef ref, BinEntity bin) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Bin'),
          content: Text(
            'Are you sure you want to delete bin ${bin.serialNumber}? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref.read(customerBinsProvider.notifier).deleteBin(bin.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete bin: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
