import 'package:flutter/material.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/core/ui/widgets/icon_tile.dart';
import 'package:slipstream/features/settings/ui/widgets/coming_soon_page.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Settings → Backup & restore. Not built yet: every button is inactive.
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ComingSoonPage(
      title: context.l10n.backupTitle,
      children: [
        SectionHeader(context.l10n.backupExportHeader),
        Container(
          padding: const .all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: .circular(18),
            border: .all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 10,
            children: [
              AccentButton(
                label: context.l10n.backupExportButton,
                height: 46,
                radius: 14,
                fontSize: 13,
                onPressed: null,
              ),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _ChipButton(
                      colors: colors,
                      label: context.l10n.backupShowQr,
                    ),
                  ),
                  Expanded(
                    child: _ChipButton(
                      colors: colors,
                      label: context.l10n.backupCopyLink,
                    ),
                  ),
                ],
              ),
              Text(
                context.l10n.backupExportNote,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SectionHeader(context.l10n.backupRestoreHeader, top: 18),
        Opacity(
          opacity: 0.45,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: colors.border),
            child: Padding(
              padding: const .symmetric(horizontal: 14, vertical: 12),
              child: Row(
                spacing: 13,
                children: [
                  IconTile(
                    iconPath: AppAssets.download,
                    color: colors.tileHue(TileHue.blue),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 2,
                      children: [
                        Text(
                          context.l10n.backupImportTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: .w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          context.l10n.backupImportSubtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Inactive secondary button (design: 42 px chip button).
class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.colors, required this.label});

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        height: 42,
        alignment: .center,
        decoration: BoxDecoration(
          color: colors.chip,
          borderRadius: .circular(13),
          border: .all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: .w600,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 1.5 px dashed rounded outline (Flutter's Border has no dashed style).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0, gap = 4.0, width = 1.5;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(16),
    );
    final paint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
