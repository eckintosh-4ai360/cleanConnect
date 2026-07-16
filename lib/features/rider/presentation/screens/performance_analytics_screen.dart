import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(riderPerformanceProvider);
    final profileAsync = ref.watch(riderProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 3),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Performance',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 12)],
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          ref.invalidate(riderPerformanceProvider);
          ref.invalidate(riderProfileProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: performanceAsync.when(
            data: (perf) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0D4), Color(0xFFFFD180)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF0A500).withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Circular score gauge
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: perf.efficiencyScore / 100,
                              strokeWidth: 10,
                              backgroundColor: Colors.white.withOpacity(0.5),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFF0A500),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${perf.efficiencyScore.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2E2A24),
                                ),
                              ),
                              const Text(
                                'Score',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6E685E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EFFICIENCY SCORE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFC78200),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _RatingStar(rating: perf.averageRating),
                            const SizedBox(height: 4),
                            Text(
                              '${perf.onTimeDeliveryRate * 100 ~/ 1}% on-time delivery',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6E685E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                perf.efficiencyScore >= 90
                                    ? '🏆 Top Performer'
                                    : perf.efficiencyScore >= 75
                                    ? '⭐ Good Standing'
                                    : '📈 Improving',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E2A24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── This Week ─────────────────────────────────────────────
                Text(
                  'This Week',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Collections',
                        value: '${perf.collectionsThisWeek}',
                        unit: 'trips',
                        icon: Icons.recycling,
                        color: const Color(0xFFE8F5E9),
                        iconColor: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Weight',
                        value: perf.weightThisWeek.toStringAsFixed(1),
                        unit: 'kg',
                        icon: Icons.scale_outlined,
                        color: const Color(0xFFE3F2FD),
                        iconColor: Colors.blue,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Week Earnings',
                        value: '\$${perf.earningsThisWeek.toStringAsFixed(2)}',
                        unit: '',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFFFFF8E1),
                        iconColor: Colors.amber.shade800,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Month Earnings',
                        value: '\$${perf.earningsThisMonth.toStringAsFixed(2)}',
                        unit: '',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFF3E5F5),
                        iconColor: Colors.purple,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Weekly Score Chart ─────────────────────────────────
                Text(
                  'Weekly Score Trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardTheme.color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last 7 Days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: _BarChart(scores: perf.weeklyScores),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                            .map(
                              (d) => Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── All-Time Stats ────────────────────────────────────────
                Text(
                  'All Time',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                profileAsync.when(
                  data: (rider) => Column(
                    children: [
                      _AllTimeStat(
                        label: 'Total Collections',
                        value: '${rider.totalCollections}',
                        icon: Icons.recycling,
                        iconColor: Colors.green,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _AllTimeStat(
                        label: 'Total Weight Collected',
                        value:
                            '${(rider.totalWeightKg / 1000).toStringAsFixed(1)} tons',
                        icon: Icons.scale_outlined,
                        iconColor: Colors.blue,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _AllTimeStat(
                        label: 'Customer Rating',
                        value: '${rider.rating.toStringAsFixed(1)} / 5.0 ★',
                        icon: Icons.star_outline,
                        iconColor: Colors.amber.shade700,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Weekly Summary Table ──────────────────────────────────
                Text(
                  'Weekly Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardTheme.color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _TableRow(
                        label: 'Complete Rate',
                        value: '${perf.onTimeDeliveryRate * 100 ~/ 1}%',
                        isHeader: true,
                      ),
                      _TableRow(label: 'Missed Stops', value: '4.8 kg'),
                      _TableRow(label: 'Top Locations', value: '11'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Recent Ratings ─────────────────────────────────────
                Text(
                  'Monthly Impact',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImpactCard(
                        label: 'Collections Done',
                        value: '${perf.collectionsThisWeek * 4}',
                        sublabel: 'this month',
                        color: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImpactCard(
                        label: 'Missed',
                        value: '0.4 kg',
                        sublabel: 'avg. miss rate',
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImpactCard(
                        label: 'Bonus Earned',
                        value: '\$285.64',
                        sublabel: 'efficiency bonus',
                        color: Colors.purple,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) =>
                const Center(child: Text('Failed to load stats.')),
          ),
        ),
      ),
    );
  }
}

// ── Sub Widgets ───────────────────────────────────────────────────────────────

class _RatingStar extends StatelessWidget {
  final double rating;
  const _RatingStar({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star, color: Color(0xFFF0A500), size: 16),
        const SizedBox(width: 4),
        Text(
          '$rating stars',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF2E2A24),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> scores;
  const _BarChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: scores.map((score) {
        final isLast = score == scores.last;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isLast
                        ? const Color(0xFFF0A500)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: (score / maxScore) * 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isLast
                          ? [const Color(0xFFF0A500), const Color(0xFFFFC94D)]
                          : [Colors.blue.shade200, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AllTimeStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _AllTimeStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHeader;
  const _TableRow({
    required this.label,
    required this.value,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isHeader ? const Color(0xFFF0A500) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final Color color;
  final bool isDark;

  const _ImpactCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            sublabel,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
