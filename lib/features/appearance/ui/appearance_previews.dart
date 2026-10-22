import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_palette.dart';

/// Miniature home screen in [palette] for a theme card. Drawn from the
/// card's own palette, not the current theme, so every card shows its look.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const .symmetric(horizontal: 7, vertical: 9),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 5,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 2),
            child: Row(
              spacing: 4,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: p.brandGradient),
                    borderRadius: .circular(3),
                  ),
                ),
                _Bar(
                  color: p.textPrimary.withValues(alpha: 0.85),
                  width: 30,
                  height: 4,
                ),
              ],
            ),
          ),
          _Card(
            palette: p,
            padding: const .all(6),
            child: Row(
              spacing: 5,
              children: [
                _Ring(color: p.ok, size: 18, width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 3,
                    children: [
                      _Bar(color: p.textPrimary, factor: 0.8),
                      _Bar(color: p.textMuted, factor: 0.5),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _MiniList(palette: p, rows: 3),
          const Spacer(),
          Container(
            height: 14,
            padding: const .all(2),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: .circular(100),
              border: .all(color: p.border),
            ),
            child: Row(
              spacing: 2,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: .circular(100),
                    ),
                  ),
                ),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Classic layout schematic: ring card on top, search, then the list.
class ClassicLayoutPreview extends StatelessWidget {
  const ClassicLayoutPreview({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const .all(9),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 6,
        children: [
          _Card(
            palette: p,
            radius: 10,
            padding: const .all(8),
            child: Row(
              spacing: 8,
              children: [
                _Ring(color: p.ok, size: 30, width: 2.5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 4,
                    children: [
                      _Bar(color: p.textPrimary, factor: 0.7, height: 4),
                      _Bar(color: p.textMuted, factor: 0.45),
                      _Bar(color: p.chip, factor: 0.85, height: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            spacing: 4,
            children: [
              Expanded(child: _Field(palette: p, height: 11)),
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: p.brandGradient),
                  borderRadius: .circular(4),
                ),
              ),
            ],
          ),
          _MiniList(palette: p, rows: 4),
        ],
      ),
    );
  }
}

/// Compact layout schematic: search, list, add buttons, slim bar at the
/// bottom.
class CompactLayoutPreview extends StatelessWidget {
  const CompactLayoutPreview({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const .all(9),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 6,
        children: [
          _Field(palette: p, height: 11),
          _MiniList(palette: p, rows: 4),
          Row(
            spacing: 4,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: p.brandGradient),
                    borderRadius: .circular(4),
                  ),
                ),
              ),
              Expanded(flex: 5, child: _Field(palette: p, height: 12)),
            ],
          ),
          const Spacer(),
          _Card(
            palette: p,
            radius: 9,
            padding: const .all(6),
            child: Row(
              spacing: 6,
              children: [
                Container(
                  width: 24,
                  height: 13,
                  padding: const .all(2),
                  alignment: .centerRight,
                  decoration: BoxDecoration(
                    color: p.chip,
                    borderRadius: .circular(100),
                  ),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: .circle, color: p.ok),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 3,
                    children: [
                      _Bar(color: p.textPrimary, factor: 0.7),
                      _Bar(color: p.textMuted, factor: 0.45),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.palette,
    required this.padding,
    required this.child,
    this.radius = 8,
  });

  final AppPalette palette;
  final EdgeInsets padding;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: .circular(radius),
        border: .all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.palette, required this.height});

  final AppPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: .circular(5),
        border: .all(color: palette.border),
      ),
    );
  }
}

/// Server list: the first row selected.
class _MiniList extends StatelessWidget {
  const _MiniList({required this.palette, required this.rows});

  final AppPalette palette;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return _Card(
      palette: p,
      padding: const .all(3),
      child: Column(
        spacing: 1,
        children: [
          for (var i = 0; i < rows; i++)
            Container(
              padding: const .symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: i == 0 ? p.selectedRow : null,
                borderRadius: .circular(5),
              ),
              child: Row(
                spacing: 5,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: .circular(3),
                    ),
                  ),
                  Expanded(
                    child: _Bar(color: p.textSecondary.withValues(alpha: 0.75)),
                  ),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(shape: .circle, color: p.ok),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.size, required this.width});

  final Color color;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: .circle,
        border: .all(color: color, width: width),
      ),
    );
  }
}

/// A text line stand-in. [factor] is its share of the available width.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    this.factor = 1,
    this.width,
    this.height = 3,
  });

  final Color color;
  final double factor;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: .circular(2)),
    );
    if (width != null) return bar;
    return FractionallySizedBox(
      alignment: .centerLeft,
      widthFactor: factor,
      child: bar,
    );
  }
}
