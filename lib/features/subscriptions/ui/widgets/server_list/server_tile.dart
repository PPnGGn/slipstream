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
    required this.onTap,
  });

  final AppColors colors;
  final VpnServer server;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      // The selected row gets a soft background and a 3 px edge on the
      // left; unselected rows keep a transparent edge so text stays aligned.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const .fromLTRB(10, 11, 10, 11),
        decoration: BoxDecoration(
          color: selected ? colors.selectedRow : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          spacing: 11,
          children: [
            Text(
              server.flagEmoji,
              style: const TextStyle(fontSize: 19, height: 1),
            ),
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
