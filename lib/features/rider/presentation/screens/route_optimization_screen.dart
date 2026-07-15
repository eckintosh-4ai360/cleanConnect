import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';
import '../../domain/entities/rider_entities.dart';

class RouteOptimizationScreen extends ConsumerStatefulWidget {
  const RouteOptimizationScreen({super.key});

  @override
  ConsumerState<RouteOptimizationScreen> createState() =>
      _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState
    extends ConsumerState<RouteOptimizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(riderActiveRouteProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Route',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 12)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Stop List'),
            Tab(text: 'Map View'),
          ],
        ),
      ),
      body: routeAsync.when(
        data: (route) {
          if (route == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 72,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Route',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your route will appear here once assigned.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _StopListTab(route: route, isDark: isDark),
              _MapViewTab(route: route),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load route.')),
      ),
    );
  }
}

// Stop List Tab

class _StopListTab extends ConsumerWidget {
  final ActiveRouteEntity route;
  final bool isDark;
  const _StopListTab({required this.route, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = route.completedStops / route.totalStops;

    return Column(
      children: [
        // Progress summary strip
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF0D4), Color(0xFFFFE0A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.routeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF2E2A24),
                        ),
                      ),
                      Text(
                        route.zone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E685E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${route.completedStops}/${route.totalStops} stops',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFF0A500),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF0A500),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stop list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: route.stops.length,
            itemBuilder: (context, index) {
              final stop = route.stops[index];
              return _StopTile(
                stop: stop,
                isDark: isDark,
                onCollect: () => _showCollectSheet(context, ref, stop),
                onProblem: () => _showProblemSheet(context, ref, stop),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCollectSheet(
    BuildContext context,
    WidgetRef ref,
    RouteStopEntity stop,
  ) {
    final weightController = TextEditingController(
      text: stop.estimatedWeightKg?.toStringAsFixed(1) ?? '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mark as Collected',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              stop.customerName,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Actual Weight (kg)',
                suffixText: 'kg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final weight =
                      double.tryParse(weightController.text) ??
                      (stop.estimatedWeightKg ?? 15.0);
                  ref
                      .read(riderActiveRouteProvider.notifier)
                      .markStopCollected(stopId: stop.id, weightKg: weight);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stop marked as collected!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Confirm Collection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProblemSheet(
    BuildContext context,
    WidgetRef ref,
    RouteStopEntity stop,
  ) {
    String selectedReason = 'Bin not found';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report a Problem',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.customerName,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                for (final reason in [
                  'Bin not found',
                  'Access blocked',
                  'Bin contaminated',
                  'Overweight / unsafe',
                  'Wrong address',
                ])
                  RadioListTile<String>(
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (v) => setModalState(() => selectedReason = v!),
                    title: Text(reason),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.red,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                    onPressed: () {
                      ref
                          .read(riderActiveRouteProvider.notifier)
                          .markStopProblem(
                            stopId: stop.id,
                            reason: selectedReason,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Problem reported: $selectedReason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    child: const Text('Report Problem'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final RouteStopEntity stop;
  final bool isDark;
  final VoidCallback onCollect;
  final VoidCallback onProblem;

  const _StopTile({
    required this.stop,
    required this.isDark,
    required this.onCollect,
    required this.onProblem,
  });

  Color get _statusColor {
    switch (stop.status) {
      case 'collected':
        return Colors.green;
      case 'problem':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      default:
        return const Color(0xFFF0A500);
    }
  }

  IconData get _statusIcon {
    switch (stop.status) {
      case 'collected':
        return Icons.check_circle;
      case 'problem':
        return Icons.error;
      case 'skipped':
        return Icons.skip_next;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color get _binColor {
    switch (stop.binType) {
      case 'recycling':
        return Colors.blue;
      case 'organic':
        return Colors.green;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = stop.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isPending
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (stop.status == 'collected'
                  ? Colors.green.shade50
                  : Colors.red.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? Colors.grey.shade200
              : (stop.status == 'collected'
                    ? Colors.green.shade200
                    : Colors.red.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop number / status
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isPending
                        ? Text(
                            '${stop.stopOrder}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _statusColor,
                            ),
                          )
                        : Icon(_statusIcon, color: _statusColor, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    stop.address,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _binColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${stop.binType[0].toUpperCase()}${stop.binType.substring(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _binColor,
                          ),
                        ),
                      ),
                      if (stop.estimatedWeightKg != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '~${stop.estimatedWeightKg!.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      if (stop.actualWeightKg != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '✓ ${stop.actualWeightKg!.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (stop.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stop.notes!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: onProblem,
                            child: const Text(
                              'Problem',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: onCollect,
                            child: const Text(
                              'Collect',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Map View Tab

class _MapViewTab extends StatelessWidget {
  final ActiveRouteEntity route;
  const _MapViewTab({required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Map placeholder (google_maps_flutter would be wired here)
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Stack(
                children: [
                  // Map placeholder visual
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CustomPaint(
                      painter: _MapPainter(stops: route.stops),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: theme.colorScheme.primary,
                      onPressed: () {},
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation,
                            color: Color(0xFFF0A500),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            route.routeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Next stop card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Builder(
              builder: (context) {
                final nextStop =
                    route.stops.where((s) => s.status == 'pending').isNotEmpty
                    ? route.stops.firstWhere((s) => s.status == 'pending')
                    : null;
                if (nextStop == null) {
                  return const Text(
                    'All stops completed!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  );
                }
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0A500).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.place,
                        color: Color(0xFFF0A500),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEXT STOP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF0A500),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            nextStop.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            nextStop.address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text(
                        'Navigate',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<RouteStopEntity> stops;
  _MapPainter({required this.stops});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a simple map-like background with roads
    final bgPaint = Paint()..color = const Color(0xFFF5F5F0);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Draw some mock roads
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width, size.height * 0.6),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.7, size.height),
      roadPaint,
    );

    // Draw stop markers
    final dotPaint = Paint();
    for (int i = 0; i < stops.length && i < 10; i++) {
      final x = (i % 4 * 0.22 + 0.1) * size.width;
      final y = (i ~/ 4 * 0.28 + 0.15) * size.height;
      final status = stops[i].status;
      dotPaint.color = status == 'collected'
          ? Colors.green
          : (status == 'problem' ? Colors.red : const Color(0xFFF0A500));
      canvas.drawCircle(Offset(x, y), 10, dotPaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
