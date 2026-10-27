import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/theme/app_colors.dart';

class ToastCard extends StatelessWidget {
  const ToastCard({super.key, required this.message, required this.onTap});

  final ToastMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = switch (message.kind) {
      ToastKind.success => colors.ok,
      ToastKind.error => colors.danger,
      ToastKind.info => colors.accentIcon,
    };
    final icon = switch (message.kind) {
      ToastKind.success => AppAssets.toastOk,
      ToastKind.error => AppAssets.toastError,
      ToastKind.info => AppAssets.toastInfo,
    };
    final dark = colors.palette.brightness == Brightness.dark;
    final subtitle = message.subtitle;

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: Container(
          clipBehavior: .antiAlias,
          decoration: BoxDecoration(
            color: Color.lerp(colors.surfaceRaised, accent, 0.17),
            borderRadius: .circular(18),
            border: .all(color: accent.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(10, 10, 20, dark ? 0.42 : 0.16),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(color: accent.withValues(alpha: 0.08), spreadRadius: 4),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const .fromLTRB(10, 10, 16, 10),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 11,
                  children: [
                    DecoratedBox(
                      key: const Key('toast-icon'),
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: SizedBox.square(
                        dimension: 30,
                        child: Center(
                          child: SvgPicture.asset(
                            icon,
                            width: 14,
                            height: 14,
                            colorFilter: .mode(colors.background, .srcIn),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            message.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: .w600,
                              height: 1.25,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const .only(top: 3),
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9.5,
                                  fontWeight: .w500,
                                  letterSpacing: 0.57,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: _TimerBar(
                  color: accent.withValues(alpha: 0.75),
                  duration: message.duration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 2 px line that eats itself from right to left while the toast lives.
/// The card's parent gives each new toast a fresh key, so a replacement
/// starts the bar over.
class _TimerBar extends StatefulWidget {
  const _TimerBar({required this.color, required this.duration});

  final Color color;
  final Duration duration;

  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Align(
        alignment: .centerLeft,
        child: FractionallySizedBox(
          key: const Key('toast-timer'),
          widthFactor: 1 - _controller.value,
          child: ColoredBox(color: widget.color),
        ),
      ),
    );
  }
}
