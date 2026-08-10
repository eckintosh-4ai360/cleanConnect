import 'package:flutter/material.dart';

/// A hand-built "slide to accept" control (Uber/Bolt-style incoming-ride
/// pattern): the rider drags the thumb to the end of the track to confirm.
/// Dragging less than the confirm threshold snaps the thumb back to start.
class SwipeToAcceptControl extends StatefulWidget {
  const SwipeToAcceptControl({
    super.key,
    required this.onConfirmed,
    this.label = 'Slide to accept',
    this.color = const Color(0xFF1DB954),
    this.height = 64,
  });

  final VoidCallback onConfirmed;
  final String label;
  final Color color;
  final double height;

  @override
  State<SwipeToAcceptControl> createState() => _SwipeToAcceptControlState();
}

class _SwipeToAcceptControlState extends State<SwipeToAcceptControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapController;
  double _dragDx = 0;
  double _snapStartDx = 0;
  double _trackWidth = 0;
  bool _confirmed = false;

  static const double _thumbSize = 56;
  static const double _confirmThreshold = 0.85;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() => _dragDx = _snapStartDx * (1 - _snapController.value));
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _maxDrag => (_trackWidth - _thumbSize).clamp(0, double.infinity);

  void _onDragUpdate(DragUpdateDetails details) {
    if (_confirmed) return;
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_confirmed || _maxDrag == 0) return;
    final progress = _dragDx / _maxDrag;
    if (progress >= _confirmThreshold) {
      setState(() {
        _confirmed = true;
        _dragDx = _maxDrag;
      });
      widget.onConfirmed();
      return;
    }
    _snapStartDx = _dragDx;
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;
        final progress =
            _maxDrag == 0 ? 0.0 : (_dragDx / _maxDrag).clamp(0.0, 1.0);

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4 + _dragDx,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
