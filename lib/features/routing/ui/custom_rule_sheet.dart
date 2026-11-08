import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
import 'package:slipstream/features/routing/cubit/custom_rules_cubit.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Opens the sheet that adds a rule, or edits (and can delete) [rule].
Future<void> showCustomRuleSheet(BuildContext context, {CustomRule? rule}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CustomRuleSheet(rule: rule),
  );
}

class _CustomRuleSheet extends StatefulWidget {
  const _CustomRuleSheet({this.rule});

  final CustomRule? rule;

  @override
  State<_CustomRuleSheet> createState() => _CustomRuleSheetState();
}

class _CustomRuleSheetState extends State<_CustomRuleSheet> {
  final _cubit = getIt<CustomRulesCubit>();
  final _vpn = getIt<VpnServiceCubit>();
  late final _input = TextEditingController(text: widget.rule?.value);
  late RuleAction _action = widget.rule?.action ?? RuleAction.proxy;
  RuleInputError? _error;
  bool _saving = false;

  bool get _editing => widget.rule != null;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final rule = widget.rule;
    final error = rule == null
        ? await _cubit.add(_input.text, _action)
        : await _cubit.update(rule.id, _input.text, _action);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    notifyIfTunnelActive(context.l10n, _vpn);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    if (rule == null || _saving) return;
    setState(() => _saving = true);
    await _cubit.remove(rule.id);
    if (!mounted) return;
    notifyIfTunnelActive(context.l10n, _vpn);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = AppColors.of(context);
        final error = _error;
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
                  SheetTitleRow(
                    iconPath: AppAssets.routing,
                    title: _editing
                        ? context.l10n.ruleEditTitle
                        : context.l10n.ruleAddTitle,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _input,
                    autofocus: !_editing,
                    keyboardType: .url,
                    textInputAction: .done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _save(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'example.com or 1.2.3.0/24',
                      enabledBorder: error != null ? errorBorder : null,
                      focusedBorder: error != null ? errorBorder : null,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      ruleInputErrorText(context.l10n, error),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: colors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SegmentedPill<RuleAction>(
                    options: [
                      for (final action in RuleAction.values)
                        (action, ruleActionTitle(context.l10n, action)),
                    ],
                    selected: _action,
                    onChanged: (action) => setState(() => _action = action),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ruleActionHint(context.l10n, _action),
                    style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  AccentButton(
                    label: _editing
                        ? context.l10n.commonSave
                        : context.l10n.ruleAddTitle,
                    fontSize: 14.5,
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _saving ? null : _delete,
                      child: Text(
                        context.l10n.ruleDelete,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: .w600,
                          color: colors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
