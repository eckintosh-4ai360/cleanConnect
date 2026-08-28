import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/shared/widgets/house_photo_thumbnail.dart';
import '../../domain/entities/pickup_request_entity.dart';
import '../providers/rider_providers.dart';
import '../widgets/swipe_to_accept_control.dart';

const int _countdownSeconds = 20;

class IncomingPickupRequestScreen extends ConsumerStatefulWidget {
  const IncomingPickupRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<IncomingPickupRequestScreen> createState() =>
      _IncomingPickupRequestScreenState();
}

class _IncomingPickupRequestScreenState
    extends ConsumerState<IncomingPickupRequestScreen> {
  Timer? _countdownTimer;
  int _secondsLeft = _countdownSeconds;
  bool _processing = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.startIncomingPickupAlert();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _onDecline(ref.read(pickupByIdProvider(widget.requestId)).value);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    NotificationService.instance.stopIncomingPickupAlert();
    super.dispose();
  }

  /// Leaves this screen. [PopScope.canPop] is false here so the rider cannot
  /// swipe the decision away, but that also makes `Navigator.maybePop()` a
  /// no-op -- it asks the route's pop disposition first and gets `doNotPop`.
  /// The screen then sat on its spinner forever. `pop()` bypasses that check,
  /// and a rider who arrived from a cold-start notification has nothing to pop
  /// back to, so fall through to their dashboard.
  void _dismiss() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/rider/home');
    }
  }

  Future<void> _onAccept(PickupRequestEntity pickup) async {
    if (_processing || _resolved) return;
    setState(() => _processing = true);
    _countdownTimer?.cancel();
    try {
      await ref
          .read(availablePickupsProvider.notifier)
          .accept(pickup.id, pickup.customerId);
      _resolved = true;
      NotificationService.instance.stopIncomingPickupAlert();
      NotificationService.instance.cancelIncomingPickupNotification(pickup.id);
      if (mounted) {
        context.go('/rider/navigation', extra: pickup);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        _dismiss();
      }
    }
  }

  Future<void> _onDecline(PickupRequestEntity? pickup) async {
    // _InfoState schedules this on a delay, so it can land after the screen is
    // already gone.
    if (_processing || _resolved || !mounted) return;
    _resolved = true;
    setState(() => _processing = true);
    _countdownTimer?.cancel();
    NotificationService.instance.stopIncomingPickupAlert();
    NotificationService.instance.cancelIncomingPickupNotification(widget.requestId);
    try {
      if (pickup != null) {
        await ref
            .read(availablePickupsProvider.notifier)
            .reject(pickup.id, pickup.customerId);
      }
    } catch (_) {
      // Declining is best-effort — the request just stays in the pool for
      // other riders regardless.
    }
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final pickupAsync = ref.watch(pickupByIdProvider(widget.requestId));

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EcoTheme.secondaryColor,
        body: SafeArea(
          child: pickupAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: EcoTheme.primaryColor),
            ),
            error: (e, _) => _InfoState(
              message: 'Could not load this request.',
              onDone: () => _onDecline(null),
            ),
            data: (pickup) {
              if (pickup == null || pickup.status != 'pending') {
                return _InfoState(
                  message: pickup == null
                      ? 'This request no longer exists.'
                      : 'This pickup was already taken.',
                  onDone: () => _onDecline(null),
                );
              }
              return _RequestContent(
                pickup: pickup,
                secondsLeft: _secondsLeft,
                processing: _processing,
                onAccept: () => _onAccept(pickup),
                onDecline: () => _onDecline(pickup),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoState extends StatefulWidget {
  const _InfoState({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_InfoState> createState() => _InfoStateState();
}

class _InfoStateState extends State<_InfoState> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestContent extends StatelessWidget {
  const _RequestContent({
    required this.pickup,
    required this.secondsLeft,
    required this.processing,
    required this.onAccept,
    required this.onDecline,
  });

  final PickupRequestEntity pickup;
  final int secondsLeft;
  final bool processing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  Color _binColor(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Colors.blue;
      case 'organic':
        return Colors.green;
      case 'hazardous':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _binIcon(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Icons.recycling;
      case 'organic':
        return Icons.eco_outlined;
      case 'hazardous':
        return Icons.warning_amber_outlined;
      default:
        return Icons.delete_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Pickup Request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _CountdownRing(secondsLeft: secondsLeft, total: _countdownSeconds),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          EcoTheme.primaryColor.withValues(alpha: 0.15),
                      child: const Icon(Icons.person,
                          color: EcoTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup.customerName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (pickup.timeSlot.isNotEmpty)
                            Text(
                              pickup.timeSlot,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickup.location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                // The rider is deciding whether to take this job in 20 seconds,
                // so the building they'd be driving to gets real estate rather
                // than a 44px thumbnail squeezed beside the address.
                if (pickup.housePhotoUrl != null &&
                    pickup.housePhotoUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      HousePhotoThumbnail(
                        photoUrl: pickup.housePhotoUrl,
                        size: 88,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Customer's house",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to enlarge',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pickup.binTypes
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _binColor(t).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: _binColor(t).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_binIcon(t), size: 13, color: _binColor(t)),
                              const SizedBox(width: 4),
                              Text(
                                t[0].toUpperCase() + t.substring(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _binColor(t),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (processing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(color: EcoTheme.primaryColor),
            )
          else ...[
            SwipeToAcceptControl(onConfirmed: onAccept),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onDecline,
              child: const Text(
                "Can't pickup",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft, required this.total});

  final int secondsLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: secondsLeft / total,
            strokeWidth: 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(EcoTheme.primaryColor),
          ),
          Text(
            '$secondsLeft',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
