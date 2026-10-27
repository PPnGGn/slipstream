import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_badge.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/protocol_tags.dart';

Future<void> showServerInfoSheet(BuildContext context, VpnServer server) {
  final media = MediaQuery.of(context);
  final maxHeight =
      media.size.height - media.viewPadding.top - kToolbarHeight - 8;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => _ServerInfoSheet(server: server),
  );
}

class _ServerInfoSheet extends StatelessWidget {
  const _ServerInfoSheet({required this.server});

  final VpnServer server;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = AppColors.of(context);
        final pretty = prettyJson(server.configJson);
        final meta = server.meta;
        final facts = [
          if (meta.host != null) meta.host!,
          if (meta.port != null) 'PORT ${meta.port}',
          if (meta.securityLabel != null && meta.securityLabel != 'NONE')
            meta.securityLabel!,
        ];

        return SafeArea(
          top: false,
          child: Padding(
            padding: const .fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              children: [
                const SheetGrabber(),
                Row(
                  spacing: 11,
                  children: [
                    Text(
                      server.flagEmoji,
                      style: const TextStyle(fontSize: 24, height: 1),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        mainAxisSize: .min,
                        spacing: 2,
                        children: [
                          Text(
                            server.displayTitle,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: .w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          ProtocolTags(meta: meta, fontSize: 9.5),
                        ],
                      ),
                    ),
                    _ServerPingPill(colors: colors, serverId: server.id),
                    CloseCircleButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final fact in facts)
                        _Fact(colors: colors, text: fact),
                    ],
                  ),
                ],
                Padding(
                  padding: const .fromLTRB(2, 10, 0, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'XRAY CONFIG',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: .w700,
                            letterSpacing: 1.3,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      _CopyButton(
                        colors: colors,
                        onTap: () {
                          copyToClipboard(
                            pretty,
                            title: 'Config copied',
                            subtitle:
                                'XRAY JSON · ${server.title.toUpperCase()}',
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: .circular(14),
                      border: .all(color: colors.border),
                    ),
                    child: SingleChildScrollView(
                      padding: const .symmetric(horizontal: 14, vertical: 12),
                      child: SelectableText(
                        pretty,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          height: 1.65,
                          fontWeight: .w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.colors, required this.text});

  final AppColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: .circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: .w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

/// Copies the config (and closes the sheet so the "Config copied" toast is
/// visible). Sits on the "XRAY CONFIG" label row, right above the config.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Copy config',
      style: IconButton.styleFrom(
        backgroundColor: colors.chip,
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: .zero,
        shape: RoundedRectangleBorder(borderRadius: .circular(10)),
      ),
      icon: SvgPicture.asset(
        AppAssets.copy,
        width: 14,
        height: 14,
        colorFilter: .mode(colors.textSecondary, .srcIn),
      ),
    );
  }
}

/// Ping pill in the sheet's header (design:
/// SlipStream App v2.dc.html's `infoPing`/`infoLatCol` fields) —
/// always the value pill regardless of the list's dots/numbers
/// setting, since this is a detail view, not a compact row.
class _ServerPingPill extends StatelessWidget {
  const _ServerPingPill({required this.colors, required this.serverId});

  final AppColors colors;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PingCubit, PingViewState, PingEntry>(
      bloc: getIt<PingCubit>(),
      selector: (view) => view.entries[serverId] ?? const PingEntry.notTested(),
      builder: (context, entry) => PingPill(colors: colors, entry: entry),
    );
  }
}
