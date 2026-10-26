import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/wave_switch.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';
import 'package:slipstream/features/split_tunnel/ui/widgets/app_icon_image.dart';

class AppSelectionRow extends StatelessWidget {
  const AppSelectionRow({
    super.key,
    required this.app,
    required this.selected,
    required this.onChanged,
    required this.loadIcon,
    this.showDivider = true,
  });

  final InstalledAppMessage app;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Future<Uint8List?> Function(String packageName) loadIcon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      behavior: .opaque,
      onTap: () => onChanged(!selected),
      child: Column(
        mainAxisSize: .min,
        children: [
          if (showDivider)
            Padding(
              padding: const .only(left: 59),
              child: Divider(height: 1, color: colors.border),
            ),
          Padding(
            padding: const .symmetric(horizontal: 14, vertical: 10),
            child: Row(
              spacing: 11,
              children: [
                AppIconImage(
                  packageName: app.packageName,
                  label: app.label,
                  loadIcon: loadIcon,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        app.label,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: .w600,
                          color: app.isSystem
                              ? colors.textSecondary
                              : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          fontWeight: .w500,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                WaveSwitch(value: selected, onChanged: onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
