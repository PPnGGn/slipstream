import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

class AppIconImage extends StatefulWidget {
  const AppIconImage({
    super.key,
    required this.packageName,
    required this.label,
    required this.loadIcon,
  });

  final String packageName;
  final String label;
  final Future<Uint8List?> Function(String packageName) loadIcon;

  @override
  State<AppIconImage> createState() => _AppIconImageState();
}

class _AppIconImageState extends State<AppIconImage> {
  late Future<Uint8List?> _icon;

  @override
  void initState() {
    super.initState();
    _icon = widget.loadIcon(widget.packageName);
  }

  @override
  void didUpdateWidget(AppIconImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _icon = widget.loadIcon(widget.packageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monogram = _Monogram(label: widget.label);
    return SizedBox(
      width: 34,
      height: 34,
      child: ClipRRect(
        borderRadius: .circular(9),
        child: FutureBuilder<Uint8List?>(
          future: _icon,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return monogram;
            return Image.memory(
              bytes,
              width: 34,
              height: 34,
              fit: .cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => monogram,
            );
          },
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final letter = label.trim().isEmpty
        ? '?'
        : label.trim().characters.first.toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chip,
        border: .all(color: colors.border),
        borderRadius: .circular(9),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 15,
            fontWeight: .w700,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
