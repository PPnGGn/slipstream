import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/protocol_colors.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';

/// `VLESS · TCP · REALITY`, each tag in its own color. One line; a long
/// tail ends with an ellipsis.
class ProtocolTags extends StatelessWidget {
  const ProtocolTags({super.key, required this.meta, this.fontSize = 9});

  final XrayServerMeta meta;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tags = meta.tagLabels;

    return Text.rich(
      TextSpan(
        children: [
          for (final (i, tag) in tags.indexed) ...[
            if (i > 0)
              TextSpan(
                text: ' · ',
                style: TextStyle(color: colors.textMuted),
              ),
            TextSpan(
              text: tag,
              style: TextStyle(color: protocolColor(tag, colors.palette)),
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: .ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: .w600,
        letterSpacing: fontSize * 0.08,
      ),
    );
  }
}
