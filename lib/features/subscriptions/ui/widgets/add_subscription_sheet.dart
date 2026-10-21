import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/qr/data/qr_image_import.dart';
import 'package:slipstream/features/qr/data/qr_scan.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

/// What the sheet does as soon as it opens (the compact layout's Paste and
/// Scan QR buttons): the result and any error show up inside the sheet.
enum AddSheetAction { paste, scan }

Future<void> showAddSubscriptionSheet(
  BuildContext context, {
  AddSheetAction? initialAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddSubscriptionSheet(initialAction: initialAction),
  );
}

class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet({this.initialAction});

  final AddSheetAction? initialAction;

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _cubit = getIt<SubscriptionsCubit>();
  final _input = TextEditingController();
  final _name = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    if (action == null) return;
    // After the first frame: the scanner route is pushed from this sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (action) {
        case AddSheetAction.paste:
          _paste();
        case AddSheetAction.scan:
          _scanQr();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _trimmedName {
    final name = _name.text.trim();
    return name.isEmpty ? null : name;
  }

  Future<void> _submit({required bool activate}) async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = activate
        ? await _cubit.addAndActivate(text, name: _trimmedName)
        : await _cubit.addFromInput(text, name: _trimmedName);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = _cubit.state.errorMessage ?? 'Could not add subscription';
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      setState(() => _error = 'Clipboard is empty');
      return;
    }
    await _addFromText(text);
  }

  Future<void> _scanQr() async {
    final text = await context.push<String>('/scan');
    if (!mounted || text == null) return;
    await _addFromText(text);
  }

  Future<void> _importFromImage() async {
    setState(() => _error = null);
    final result = await getIt<QrImageImporter>().import();
    if (!mounted) return;
    switch (result) {
      case QrImportCancelled():
        return;
      case QrImportNotFound():
        setState(() => _error = 'No QR code found in this image');
      case QrImportFound(:final text):
        await _addFromText(text);
    }
  }

  // Shared by Paste, Scan QR and Image: the text goes into the field and is
  // added right away, so a bad value shows up in the field and in the error.
  Future<void> _addFromText(String text) async {
    _input.text = text;
    await _submit(activate: true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const .fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const .only(bottom: 14),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: .circular(100),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add subscription',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Transform.rotate(
                          angle: math.pi / 4,
                          child: SvgPicture.asset(
                            AppAssets.plus,
                            width: 14,
                            height: 14,
                            colorFilter: .mode(colors.textSecondary, .srcIn),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _input,
                    minLines: 3,
                    maxLines: 5,
                    keyboardType: .multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'https://…, vless://…, vmess://…, trojan://…, hy2://…, ss://… or JSON',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBox(colors: colors, message: _error!),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    spacing: 8,
                    children: [
                      if (isQrScanSupported(defaultTargetPlatform))
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _scanQr,
                            icon: SvgPicture.asset(
                              AppAssets.scanQr,
                              width: 15,
                              height: 15,
                              colorFilter: .mode(colors.textPrimary, .srcIn),
                            ),
                            label: const Text('Scan QR'),
                          ),
                        ),
                      if (isQrScanSupported(defaultTargetPlatform))
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _importFromImage,
                            icon: SvgPicture.asset(
                              AppAssets.doc,
                              width: 15,
                              height: 15,
                              colorFilter: .mode(colors.textPrimary, .srcIn),
                            ),
                            label: const Text('Image'),
                          ),
                        ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _paste,
                          icon: SvgPicture.asset(
                            AppAssets.copy,
                            width: 15,
                            height: 15,
                            colorFilter: .mode(colors.textPrimary, .srcIn),
                          ),
                          label: const Text('Paste'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    textInputAction: .done,
                    decoration: const InputDecoration(
                      hintText: 'Name (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bulk add: separate several links with ; or a new line',
                    style: textTheme.labelSmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(activate: false),
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Text('Add subscription'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.colors, required this.message});

  final AppColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.13),
        borderRadius: .circular(12),
        border: .all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.danger, fontSize: 12, height: 1.5),
      ),
    );
  }
}
