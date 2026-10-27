import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/ui/toast/toast_card.dart';

/// Puts the current toast over the whole app. It sits in `MaterialApp.builder`,
/// above the Navigator, so a toast is visible over bottom sheets and dialogs
/// too. It only decides where the card goes and how it comes and goes; what is
/// shown, and for how long, is [ToastCubit]'s business.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.cubit, required this.child});

  final ToastCubit cubit;
  final Widget child;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost>
    with SingleTickerProviderStateMixin {
  // Kept after the cubit goes back to null, so the card can fade out instead
  // of vanishing: this is what is drawn, the cubit is what should be shown.
  ToastMessage? _drawn;
  StreamSubscription<ToastMessage?>? _subscription;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 150),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.2, 0.9, 0.3, 1.2),
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onAnimationStatus);
    _subscription = widget.cubit.stream.listen(_onMessage);
    final current = widget.cubit.state;
    if (current != null) _onMessage(current);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMessage(ToastMessage? message) {
    if (message == null) {
      _controller.reverse();
      return;
    }
    setState(() => _drawn = message);
    _controller.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    // forward(from: 0) passes through "dismissed" for a moment: only a
    // finished fade-out with nothing new waiting may drop the card.
    if (status == AnimationStatus.dismissed && widget.cubit.state == null) {
      setState(() => _drawn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _drawn;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: math.max(92, keyboard + 12),
            child: IgnorePointer(
              ignoring: widget.cubit.state == null,
              child: AnimatedBuilder(
                animation: _curve,
                builder: (context, child) => Opacity(
                  opacity: _curve.value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - _curve.value)),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * _curve.value,
                      child: child,
                    ),
                  ),
                ),
                // Above the Navigator there is no Material, and without one
                // the text would get the debug yellow underline.
                child: Material(
                  type: .transparency,
                  child: Center(
                    child: ToastCard(
                      key: ValueKey(message.id),
                      message: message,
                      onTap: widget.cubit.dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
