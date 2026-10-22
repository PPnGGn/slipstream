import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// Mono caps label above a settings group.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.top = 22});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

/// Card holding settings rows, divided by lines that start after the icon
/// tile. A Material, so row ripples paint on the card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 63),
                child: Divider(height: 1, color: colors.border),
              ),
            child,
          ],
        ],
      ),
    );
  }
}
