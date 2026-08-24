import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/rider_providers.dart';
import '../widgets/rider_nav_bar.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../../domain/entities/bin_verification_result.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class RiderCollectionScreen extends ConsumerStatefulWidget {
  final PickupRequestEntity? pickup;

  const RiderCollectionScreen({super.key, this.pickup});

  @override
  ConsumerState<RiderCollectionScreen> createState() =>
      _RiderCollectionScreenState();
}

class _RiderCollectionScreenState
    extends ConsumerState<RiderCollectionScreen> {
  bool _scanMode = false;
  bool _scanned = false;
  String? _scannedCode;

  /// The pickup this scan will complete. Seeded from [widget.pickup] when
  /// opened from the navigation flow; left null when opened generically
  /// (dashboard "Scan Collection" quick action, bottom-nav Collections tab)
  /// so the rider is asked to pick one instead of the scan silently having
  /// nothing to complete against.
  PickupRequestEntity? _activePickup;

  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// True while a scanned code is being checked against verify_pickup_bin.
  /// Guards onDetect against firing again for every frame the code stays in
  /// view while a request is already in flight.
  bool _verifying = false;

  /// The last code that failed verification, so a still-in-frame QR doesn't
  /// spam the RPC and stack up error SnackBars every frame.
  String? _lastFailedCode;

  /// Bin details from a successful verify_pickup_bin call, shown on the
  /// confirmation card instead of the pickup's general bin_types.
  BinVerificationResult? _verification;

  @override
  void initState() {
    super.initState();
    _activePickup = widget.pickup;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_verifying || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty || code == _lastFailedCode) return;

    final pickup = _activePickup;
    if (pickup == null) return;

    setState(() => _verifying = true);
    try {
      final result = await ref
          .read(availablePickupsProvider.notifier)
          .verifyBin(requestId: pickup.id, serialNumber: code);
      if (!mounted) return;
      if (result.verified) {
        setState(() {
          _scanned = true;
          _scannedCode = code;
          _verification = result;
          _verifying = false;
          _lastFailedCode = null;
        });
      } else {
        setState(() {
          _verifying = false;
          _lastFailedCode = code;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _lastFailedCode = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not verify bin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(riderCollectionHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 3),
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
    if (_activePickup == null) {
      return _buildPickupPicker(context);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_scanned) ...[
            // Real camera QR scanner -- matched server-side against the
            // scanned pickup's customer in verify_pickup_bin.
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _handleDetect,
                      errorBuilder: (context, error) => Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            error.errorCode == MobileScannerErrorCode.permissionDenied
                                ? 'Camera permission is required to scan a bin. '
                                    'Enable it in your device settings and try again.'
                                : error.errorCode.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ..._buildCornerGuides(),
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: theme.colorScheme.primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          Positioned(child: _ScanLine()),
                          Positioned(
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _verifying
                                    ? 'Checking bin…'
                                    : "Point camera at the customer's bin QR code",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_verifying)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Scan Result
            _ScanResultCard(
              code: _scannedCode!,
              pickup: _activePickup!,
              verification: _verification,
              onConfirm: (weight, notes) async {
                final pickup = _activePickup;
                final code = _scannedCode;
                if (pickup == null || code == null) {
                  throw StateError('No verified bin scan to complete.');
                }
                // Persist the collection and clear the customer's "next
                // pickup" banner -- this is the only call in the app that
                // actually marks a pickup_requests row completed, so
                // skipping it (as the old code silently did when opened
                // without a specific pickup) left the customer's "on the
                // way" banner stuck forever even though the rider saw a
                // success message here. complete_pickup re-checks the QR
                // code server-side too, so this can't be bypassed by a
                // modified client skipping the scan.
                await ref
                    .read(availablePickupsProvider.notifier)
                    .complete(
                      requestId: pickup.id,
                      customerId: pickup.customerId,
                      weightKg: weight,
                      qrCodeData: code,
                      notes: notes,
                    );
                if (!context.mounted) return;
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
                  _verification = null;
                  _lastFailedCode = null;
                  _scanMode = false;
                  // Back to null (unless this screen was opened for one
                  // specific job) so the next scan asks again instead of
                  // re-completing the same now-finished pickup.
                  _activePickup = widget.pickup;
                });
              },
              onRetry: () => setState(() {
                _scanned = false;
                _scannedCode = null;
                _verification = null;
                _lastFailedCode = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  /// Shown instead of the scanner when this screen was opened without a
  /// specific job (dashboard quick action / bottom nav) -- lets the rider
  /// choose which of their accepted pickups the scan is for, rather than
  /// the scan having nothing to actually complete.
  Widget _buildPickupPicker(BuildContext context) {
    final acceptedAsync = ref.watch(riderAcceptedPickupsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: acceptedAsync.when(
        data: (pickups) {
          if (pickups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'You have no accepted pickups to collect right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Which pickup are you collecting?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the job this scan is for.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...pickups.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_shipping_outlined),
                    ),
                    title: Text(
                      p.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${p.binTypes.join(', ')} • ${p.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _activePickup = p),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: Text('Failed to load your accepted pickups.')),
        ),
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
  final PickupRequestEntity pickup;
  final BinVerificationResult? verification;
  final Future<void> Function(double weight, String? notes) onConfirm;
  final VoidCallback onRetry;
  const _ScanResultCard({
    required this.code,
    required this.pickup,
    this.verification,
    required this.onConfirm,
    required this.onRetry,
  });

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
              _InfoRow(label: 'Bin Serial', value: widget.code),
              _InfoRow(
                label: 'Type',
                value: widget.verification?.binType ??
                    (widget.pickup.binTypes.isEmpty
                        ? 'General Waste'
                        : widget.pickup.binTypes.join(', ')),
              ),
              if (widget.verification?.binSize != null)
                _InfoRow(label: 'Size', value: widget.verification!.binSize!),
              _InfoRow(label: 'Customer', value: widget.pickup.customerName),
              _InfoRow(label: 'Address', value: widget.pickup.location),
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
                : () async {
                    setState(() => _uploading = true);
                    try {
                      await widget.onConfirm(
                        double.tryParse(_weightCtrl.text) ?? 18.0,
                        _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
                      );
                    } catch (e) {
                      if (mounted) {
                        setState(() => _uploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to log collection: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
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
