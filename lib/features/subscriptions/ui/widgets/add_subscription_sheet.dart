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
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
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
        final colors = AppColors.of(context);
        final scanSupported = isQrScanSupported(defaultTargetPlatform);
        final errorBorder = OutlineInputBorder(
          borderRadius: .circular(14),
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        );

        return Padding(
          padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const .fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  const SheetGrabber(),
                  const SheetTitleRow(
                    iconPath: AppAssets.link,
                    title: 'Add subscription',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _input,
                    minLines: 3,
                    maxLines: 5,
                    keyboardType: .multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'https://…, vless://…, vmess://…, trojan://…, hy2://…, ss://… or JSON',
                      // A failed add outlines the field it came from.
                      enabledBorder: _error != null ? errorBorder : null,
                      focusedBorder: _error != null ? errorBorder : null,
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
                      if (scanSupported)
                        Expanded(
                          child: _ChipButton(
                            colors: colors,
                            iconPath: AppAssets.scanQr,
                            label: 'Scan QR',
                            onTap: _busy ? null : _scanQr,
                          ),
                        ),
                      if (scanSupported)
                        Expanded(
                          child: _ChipButton(
                            colors: colors,
                            iconPath: AppAssets.doc,
                            label: 'Image',
                            onTap: _busy ? null : _importFromImage,
                          ),
                        ),
                      Expanded(
                        child: _ChipButton(
                          colors: colors,
                          iconPath: AppAssets.paste,
                          label: 'Paste',
                          onTap: _busy ? null : _paste,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    textInputAction: .done,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: .w500,
                      color: colors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Name (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bulk add: separate several links with ; or a new line',
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  AccentButton(
                    label: _busy ? 'Fetching servers…' : 'Add subscription',
                    fontSize: 14.5,
                    loading: _busy,
                    onPressed: () => _submit(activate: false),
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

/// Small secondary action under the link field (design: 38 px chip button).
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.colors,
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String iconPath;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: .circular(12),
            border: .all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: .center,
            spacing: 7,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 13,
                height: 13,
                colorFilter: .mode(colors.textPrimary, .srcIn),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: .w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const .symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.13),
        borderRadius: .circular(12),
        border: .all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Padding(
            padding: const .only(top: 1),
            child: SvgPicture.asset(
              AppAssets.info,
              width: 14,
              height: 14,
              colorFilter: .mode(colors.danger, .srcIn),
            ),
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.danger, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
