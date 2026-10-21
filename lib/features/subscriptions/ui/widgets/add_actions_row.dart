import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/features/qr/data/qr_scan.dart';

/// Compact layout only: Add / Paste / Scan QR under the server list. The
/// classic layout has just the "+" in the header.
class AddActionsRow extends StatelessWidget {
  const AddActionsRow({
    super.key,
    required this.onAdd,
    required this.onPaste,
    required this.onScan,
  });

  final VoidCallback onAdd;
  final VoidCallback onPaste;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();

    return Padding(
      padding: const .only(top: 4),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 6,
            child: AccentButton(
              label: 'Add',
              iconPath: AppAssets.plus,
              onPressed: onAdd,
            ),
          ),
          Expanded(
            flex: 5,
            child: _OutlineButton(
              colors: colors,
              onTap: onPaste,
              iconPath: AppAssets.paste,
              label: 'Paste',
            ),
          ),
          if (isQrScanSupported(defaultTargetPlatform))
            SizedBox(
              width: 50,
              child: _OutlineButton(
                colors: colors,
                onTap: onScan,
                iconPath: AppAssets.scanQr,
              ),
            ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.colors,
    required this.onTap,
    required this.iconPath,
    this.label,
  });

  final AppColors colors;
  final VoidCallback onTap;
  final String iconPath;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: .circular(15),
          border: .all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: .center,
          spacing: 8,
          children: [
            SvgPicture.asset(
              iconPath,
              width: label == null ? 18 : 15,
              height: label == null ? 18 : 15,
              colorFilter: .mode(colors.textSecondary, .srcIn),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: .w600,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
