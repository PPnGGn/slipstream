import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_badge.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/protocol_tags.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/server_info_sheet.dart';

class ServerTile extends StatelessWidget {
  const ServerTile({
    super.key,
    required this.colors,
    required this.server,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onLongPress,
  });

  final AppColors colors;
  final VpnServer server;
  final bool selected;

  /// Pinned by the user: a heart on the flag.
  final bool favorite;
  final VoidCallback onTap;

  /// Pins or unpins the server.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: .opaque,
      // The selected row is a rounded, softly lit frame. Unselected rows keep
      // a transparent frame of the same size, so text stays aligned.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const .symmetric(horizontal: 6, vertical: 2),
        padding: const .fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: selected ? colors.selectedRow : Colors.transparent,
          borderRadius: .circular(14),
          border: .all(
            color: selected
                ? colors.primary.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          spacing: 11,
          children: [
            _Flag(colors: colors, server: server, favorite: favorite),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: 3,
                children: [
                  Text(
                    server.displayTitle,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? .w700 : .w500,
                      color: selected
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                  ProtocolTags(meta: server.meta),
                ],
              ),
            ),
            PingBadge(serverId: server.id, colors: colors),
            GestureDetector(
              onTap: () => showServerInfoSheet(context, server),
              behavior: .opaque,
              child: SizedBox.square(
                dimension: 30,
                child: Center(
                  child: SvgPicture.asset(
                    AppAssets.info,
                    width: 16,
                    height: 16,
                    colorFilter: .mode(colors.textMuted, .srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The country flag; a favorite server gets a small heart in its corner.
class _Flag extends StatelessWidget {
  const _Flag({
    required this.colors,
    required this.server,
    required this.favorite,
  });

  final AppColors colors;
  final VpnServer server;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 26,
      child: Stack(
        clipBehavior: .none,
        alignment: .center,
        children: [
          Text(
            server.flagEmoji,
            style: const TextStyle(fontSize: 19, height: 1),
          ),
          if (favorite)
            Positioned(
              right: -5,
              bottom: -4,
              child: Container(
                width: 14,
                height: 14,
                alignment: .center,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: colors.surface,
                  border: .all(color: colors.border),
                ),
                child: SvgPicture.asset(
                  AppAssets.heart,
                  width: 8,
                  height: 8,
                  colorFilter: .mode(colors.danger, .srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
