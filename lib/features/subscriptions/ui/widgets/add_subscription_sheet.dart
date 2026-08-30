import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

Future<void> showAddSubscriptionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AddSubscriptionSheet(),
  );
}

class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet();

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
    _input.text = text;
    await _submit(activate: true);
  }

  void _scanQr() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('QR scanning is not available yet')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
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
                      hintText: 'https://…, vless://…, ss://…, trojan://… or JSON',
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
