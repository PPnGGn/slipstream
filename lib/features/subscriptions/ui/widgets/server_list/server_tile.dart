import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/features/subscriptions/data/ping/ping_quality.dart';
import 'package:slipstream/features/subscriptions/data/ping/ping_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/server_info_sheet.dart';

class ServerTile extends StatelessWidget {
  const ServerTile({
    super.key,
    required this.colors,
    required this.server,
    required this.selected,
    required this.pingDelay,
    required this.onTap,
  });

  final AppColors colors;
  final VpnServer server;
  final bool selected;
  final Duration pingDelay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = server.meta;

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 2),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.06),
                  borderRadius: .circular(12),
                  border: .all(color: colors.primary.withValues(alpha: 0.7)),
                )
              : null,
          padding: const .fromLTRB(6, 8, 4, 8),
          child: Row(
            spacing: 10,
            children: [
              _FlagBox(colors: colors, flag: server.flagEmoji),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    Text(
                      server.displayTitle,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: .w600,
                        color: selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _ProtoChips(colors: colors, meta: meta),
                  ],
                ),
              ),
              if (meta.hasEndpoint)
                _PingPill(
                  colors: colors,
                  host: meta.host!,
                  port: meta.port!,
                  delay: pingDelay,
                ),
              GestureDetector(
                onTap: () => showServerInfoSheet(context, server),
                behavior: .opaque,
                child: Padding(
                  padding: const .all(6),
                  child: SvgPicture.asset(
                    AppAssets.info,
                    width: 16,
                    height: 16,
                    colorFilter: .mode(colors.textMuted, .srcIn),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.colors, required this.flag});

  final AppColors colors;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: .center,
      decoration: BoxDecoration(color: colors.chip, borderRadius: .circular(9)),
      child: Text(flag, style: const TextStyle(fontSize: 17, height: 1)),
    );
  }
}

class _ProtoChips extends StatelessWidget {
  const _ProtoChips({required this.colors, required this.meta});

  final AppColors colors;
  final XrayServerMeta meta;

  @override
  Widget build(BuildContext context) {
    final tail = [
      meta.networkLabel,
      meta.securityLabel,
    ].whereType<String>().join(' · ');

    return Row(
      children: [
        Container(
          padding: const .symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: .circular(4),
          ),
          child: Text(
            meta.protocolLabel,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8.5,
              fontWeight: .w700,
              letterSpacing: 0.5,
              color: colors.textSecondary,
            ),
          ),
        ),
        if (tail.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const .only(left: 6),
              child: Text(
                '· $tail',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8.5,
                  fontWeight: .w600,
                  letterSpacing: 0.4,
                  color: colors.textMuted,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class _PingPill extends StatefulWidget {
  const _PingPill({
    required this.colors,
    required this.host,
    required this.port,
    required this.delay,
  });

  final AppColors colors;
  final String host;
  final int port;
  final Duration delay;

  @override
  State<_PingPill> createState() => _PingPillState();
}

class _PingPillState extends State<_PingPill> {
  PingQuality? _quality;
  Duration? _rtt;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    final rtt = await getIt<PingService>().ping(widget.host, widget.port);
    if (!mounted) return;
    setState(() {
      _rtt = rtt;
      _quality = PingQuality.of(rtt);
    });
  }

  Color _colorFor(PingQuality quality) => switch (quality) {
    PingQuality.good => widget.colors.ok,
    PingQuality.fair => widget.colors.warn,
    PingQuality.poor || PingQuality.timeout => widget.colors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final quality = _quality;

    if (quality == null) {
      return SizedBox(
        width: 46,
        height: 18,
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation(colors.textMuted),
            ),
          ),
        ),
      );
    }

    final color = _colorFor(quality);
    final ms = _rtt?.inMilliseconds;
    final label = ms == null ? 'timeout' : '$ms ms';

    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: .circular(100),
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: 5,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: .circle, color: color),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: .w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
