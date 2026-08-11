import 'package:flutter/material.dart';
import 'package:slipstream/app/theme.dart';

enum ConnectButtonStatus { idle, busy, connected, error }

class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.status,
    required this.onTap,
    this.enabled = true,
  });

  final ConnectButtonStatus status;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _isIdle => widget.status == ConnectButtonStatus.idle;
  bool get _isBusy => widget.status == ConnectButtonStatus.busy;

  Color get _accent => switch (widget.status) {
    ConnectButtonStatus.idle => AppColors.textMuted,
    ConnectButtonStatus.busy => AppColors.amberBusy,
    ConnectButtonStatus.connected => AppColors.green19FF90,
    ConnectButtonStatus.error => AppColors.redFF6A55,
  };

  List<Color> get _ringGradient => _isIdle
      ? AppColors.grayGradient
      : [_accent, Color.lerp(_accent, AppColors.blue48FDFF, 0.35)!];

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = _isIdle ? 0.0 : 0.30 + _pulse.value * 0.25;
          return Container(
            height: 180,
            width: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(colors: AppColors.buttonGradient),
              boxShadow: [
                BoxShadow(
                  blurRadius: 44,
                  spreadRadius: -6,
                  color: accent.withValues(alpha: glow),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _ringGradient),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.buttonGradient,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.grayGradient,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _ringGradient),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.grayGradient,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Center(child: _buildCenter(accent)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenter(Color accent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isBusy)
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        Icon(Icons.power_settings_new_rounded, size: 46, color: accent),
      ],
    );
  }
}
