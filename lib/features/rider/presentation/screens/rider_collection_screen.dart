import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderCollectionScreen extends ConsumerStatefulWidget {
  const RiderCollectionScreen({super.key});

  @override
  ConsumerState<RiderCollectionScreen> createState() =>
      _RiderCollectionScreenState();
}

class _RiderCollectionScreenState
    extends ConsumerState<RiderCollectionScreen> {
  bool _scanMode = false;
  bool _scanned = false;
  String? _scannedCode;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(riderCollectionHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 2),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          _scanMode ? 'Scan QR Code' : 'Collections',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _scanMode ? Icons.list_alt_outlined : Icons.qr_code_scanner,
            ),
            onPressed: () => setState(() {
              _scanMode = !_scanMode;
              _scanned = false;
              _scannedCode = null;
            }),
            tooltip: _scanMode ? 'View History' : 'Scan QR',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _scanMode ? _buildScanView(context) : _buildHistoryView(historyAsync, theme),
    );
  }

  Widget _buildScanView(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_scanned) ...[
            // QR Scanner Placeholder
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Corner guides
                  ..._buildCornerGuides(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code,
                            size: 80, color: Colors.white38),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Point camera at bin QR code',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  // Simulated scan line
                  Positioned(
                    child: _ScanLine(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Or tap below to simulate a scan',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _scanned = true;
                  _scannedCode = 'BIN-GEN-0042';
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ] else ...[
            // Scan Result
            _ScanResultCard(
              code: _scannedCode!,
              onConfirm: (weight, notes) {
                ref
                    .read(riderCollectionHistoryProvider.notifier);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Collection verified and logged!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                setState(() {
                  _scanned = false;
                  _scannedCode = null;
                  _scanMode = false;
                });
              },
              onRetry: () => setState(() {
                _scanned = false;
                _scannedCode = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCornerGuides() {
    const size = 20.0;
    const thickness = 3.0;
    const color = Color(0xFFF0A500);
    final corners = [
      Positioned(top: 40, left: 40,
          child: _CornerGuide(top: true, left: true, size: size, thickness: thickness, color: color)),
      Positioned(top: 40, right: 40,
          child: _CornerGuide(top: true, left: false, size: size, thickness: thickness, color: color)),
      Positioned(bottom: 40, left: 40,
          child: _CornerGuide(top: false, left: true, size: size, thickness: thickness, color: color)),
      Positioned(bottom: 40, right: 40,
          child: _CornerGuide(top: false, left: false, size: size, thickness: thickness, color: color)),
    ];
    return corners;
  }

  Widget _buildHistoryView(AsyncValue historyAsync, ThemeData theme) {
    return historyAsync.when(
      data: (logs) {
        // Summary row
        final verified = (logs as List).where((l) => l.status == 'verified').length;
        final totalWeight =
            logs.fold<double>(0.0, (sum, l) => sum + (l.weightKg as double));

        return Column(
          children: [
            // Summary strip
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryChip(
                      value: '${logs.length}',
                      label: 'Total',
                      icon: Icons.list_alt),
                  _SummaryChip(
                      value: '$verified',
                      label: 'Verified',
                      icon: Icons.verified),
                  _SummaryChip(
                      value: '${totalWeight.toStringAsFixed(0)} kg',
                      label: 'Weight',
                      icon: Icons.scale),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _CollectionHistoryCard(log: log, theme: theme);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load.')),
    );
  }
}

// ── Sub Widgets ───────────────────────────────────────────────────────────────

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: -100, end: 100).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 200,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFF0A500).withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerGuide extends StatelessWidget {
  final bool top, left;
  final double size, thickness;
  final Color color;
  const _CornerGuide(
      {required this.top,
      required this.left,
      required this.size,
      required this.thickness,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            top: top, left: left, color: color, thickness: thickness),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top, left;
  final Color color;
  final double thickness;
  _CornerPainter(
      {required this.top,
      required this.left,
      required this.color,
      required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _ScanResultCard extends StatefulWidget {
  final String code;
  final void Function(double weight, String? notes) onConfirm;
  final VoidCallback onRetry;
  const _ScanResultCard(
      {required this.code, required this.onConfirm, required this.onRetry});

  @override
  State<_ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<_ScanResultCard> {
  final _weightCtrl = TextEditingController(text: '18.0');
  final _notesCtrl = TextEditingController();
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Success indicator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: Colors.green, size: 56),
        ),
        const SizedBox(height: 16),
        const Text('Bin Verified!',
            style:
                TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 4),
        Text(widget.code,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 24),

        // Bin info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Bin ID', value: widget.code),
              _InfoRow(label: 'Type', value: 'General Waste'),
              _InfoRow(label: 'Customer', value: 'Fatima Al-Hassan'),
              _InfoRow(label: 'Address', value: '67 Mango Boulevard'),
              const Divider(height: 24),
              const Text('Actual Weight (kg)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  suffixText: 'kg',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Notes (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any special observations...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _uploading
                ? null
                : () {
                    setState(() => _uploading = true);
                    Future.delayed(const Duration(milliseconds: 1200), () {
                      if (mounted) {
                        widget.onConfirm(
                          double.tryParse(_weightCtrl.text) ?? 18.0,
                          _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
                        );
                      }
                    });
                  },
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_uploading ? 'Uploading...' : 'Confirm Collection'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.onRetry,
          child: const Text('Scan Again'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _SummaryChip(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFF0A500), size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6E685E))),
      ],
    );
  }
}

class _CollectionHistoryCard extends StatelessWidget {
  final dynamic log;
  final ThemeData theme;
  const _CollectionHistoryCard({required this.log, required this.theme});

  Color _binColor(String type) {
    switch (type) {
      case 'recycling':
        return Colors.blue;
      case 'organic':
        return Colors.green;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'verified':
        return Colors.green;
      case 'problem':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _binColor(log.binType).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.delete, color: _binColor(log.binType), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(log.address,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, h:mm a').format(log.collectedAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (log.notes != null)
                    Text(log.notes!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${log.weightKg} kg',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(log.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.status == 'pending_review'
                        ? 'Review'
                        : '${log.status[0].toUpperCase()}${log.status.substring(1)}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(log.status)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
