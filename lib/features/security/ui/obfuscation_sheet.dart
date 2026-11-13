import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
import 'package:slipstream/features/security/cubit/obfuscation_cubit.dart';
import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/features/security/ui/obfuscation_labels.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Opens the sheet that edits how Fragment cuts the first packets.
Future<void> showFragmentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _FragmentSheet(),
  );
}

/// Opens the sheet that edits the junk Noise sends ahead of the first packet.
Future<void> showNoiseSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _NoiseSheet(),
  );
}

class _FragmentSheet extends StatefulWidget {
  const _FragmentSheet();

  @override
  State<_FragmentSheet> createState() => _FragmentSheetState();
}

class _FragmentSheetState extends State<_FragmentSheet> {
  final _cubit = getIt<ObfuscationCubit>();
  final _vpn = getIt<VpnServiceCubit>();
  late final _packets = TextEditingController(
    text: _cubit.state.fragment.packets,
  );
  late final _length = TextEditingController(
    text: _cubit.state.fragment.length,
  );
  late final _delay = TextEditingController(text: _cubit.state.fragment.delay);
  FragmentErrors? _errors;
  bool _saving = false;

  @override
  void dispose() {
    _packets.dispose();
    _length.dispose();
    _delay.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_errors != null) setState(() => _errors = null);
  }

  void _reset() {
    const defaults = FragmentParams();
    setState(() {
      _packets.text = defaults.packets;
      _length.text = defaults.length;
      _delay.text = defaults.delay;
      _errors = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final errors = await _cubit.saveFragment(
      FragmentParams(
        packets: _packets.text,
        length: _length.text,
        delay: _delay.text,
      ),
    );
    if (!mounted) return;
    if (errors != null) {
      setState(() {
        _saving = false;
        _errors = errors;
      });
      return;
    }
    notifyIfTunnelActive(context.l10n, _vpn);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errors = _errors;
    String? text(RangeInputError? error, RangeBounds bounds) => error == null
        ? null
        : rangeErrorText(l10n, error, min: bounds.min, max: bounds.max);

    return _SheetShell(
      iconPath: AppAssets.chip,
      title: l10n.fragmentSheetTitle,
      saving: _saving,
      onSave: _save,
      onReset: _reset,
      fields: [
        _RangeField(
          controller: _packets,
          label: l10n.fragmentPacketsLabel,
          hint: l10n.fragmentPacketsHint,
          error: errors?.packets == null
              ? null
              : fragmentPacketsErrorText(l10n, errors!.packets!),
          numeric: false,
          onChanged: _clearErrors,
        ),
        _RangeField(
          controller: _length,
          label: l10n.fragmentLengthLabel,
          hint: l10n.fragmentLengthHint,
          error: text(errors?.length, fragmentLengthBounds),
          onChanged: _clearErrors,
        ),
        _RangeField(
          controller: _delay,
          label: l10n.obfuscationDelayLabel,
          hint: l10n.obfuscationDelayHint,
          error: text(errors?.delay, delayBounds),
          onChanged: _clearErrors,
        ),
      ],
    );
  }
}

class _NoiseSheet extends StatefulWidget {
  const _NoiseSheet();

  @override
  State<_NoiseSheet> createState() => _NoiseSheetState();
}

class _NoiseSheetState extends State<_NoiseSheet> {
  final _cubit = getIt<ObfuscationCubit>();
  final _vpn = getIt<VpnServiceCubit>();
  late final _size = TextEditingController(text: _cubit.state.noise.size);
  late final _delay = TextEditingController(text: _cubit.state.noise.delay);
  NoiseErrors? _errors;
  bool _saving = false;

  @override
  void dispose() {
    _size.dispose();
    _delay.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_errors != null) setState(() => _errors = null);
  }

  void _reset() {
    const defaults = NoiseParams();
    setState(() {
      _size.text = defaults.size;
      _delay.text = defaults.delay;
      _errors = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final errors = await _cubit.saveNoise(
      NoiseParams(size: _size.text, delay: _delay.text),
    );
    if (!mounted) return;
    if (errors != null) {
      setState(() {
        _saving = false;
        _errors = errors;
      });
      return;
    }
    notifyIfTunnelActive(context.l10n, _vpn);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errors = _errors;
    String? text(RangeInputError? error, RangeBounds bounds) => error == null
        ? null
        : rangeErrorText(l10n, error, min: bounds.min, max: bounds.max);

    return _SheetShell(
      iconPath: AppAssets.sparkle,
      title: l10n.noiseSheetTitle,
      saving: _saving,
      onSave: _save,
      onReset: _reset,
      fields: [
        _RangeField(
          controller: _size,
          label: l10n.noiseSizeLabel,
          hint: l10n.noiseSizeHint,
          error: text(errors?.size, noiseSizeBounds),
          onChanged: _clearErrors,
        ),
        _RangeField(
          controller: _delay,
          label: l10n.obfuscationDelayLabel,
          hint: l10n.obfuscationDelayHint,
          error: text(errors?.delay, delayBounds),
          onChanged: _clearErrors,
        ),
      ],
    );
  }
}

/// The chrome both sheets share: title, the fields, Save and the reset button.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.iconPath,
    required this.title,
    required this.fields,
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  final String iconPath;
  final String title;
  final List<Widget> fields;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = AppColors.of(context);
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
                  SheetTitleRow(iconPath: iconPath, title: title),
                  const SizedBox(height: 16),
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  AccentButton(
                    label: context.l10n.commonSave,
                    fontSize: 14.5,
                    loading: saving,
                    onPressed: onSave,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: saving ? null : onReset,
                    child: Text(
                      context.l10n.obfuscationReset,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: .w600,
                        color: colors.textMuted,
                      ),
                    ),
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

/// One text field of a sheet: monospace like the rule sheet, with the error
/// under it and a red frame while there is one.
class _RangeField extends StatelessWidget {
  const _RangeField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.error,
    this.numeric = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? error;
  final bool numeric;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final errorBorder = OutlineInputBorder(
      borderRadius: .circular(14),
      borderSide: BorderSide(color: colors.danger, width: 1.5),
    );
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(signed: true)
          : TextInputType.text,
      textInputAction: .next,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => onChanged(),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        errorStyle: TextStyle(fontSize: 11.5, height: 1.4, color: colors.danger),
        enabledBorder: error != null ? errorBorder : null,
        focusedBorder: error != null ? errorBorder : null,
      ),
    );
  }
}
