import 'package:flutter/material.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/app/theme.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

Future<void> showAddSubscriptionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const AddSubscriptionDialog(),
  );
}

class AddSubscriptionDialog extends StatefulWidget {
  const AddSubscriptionDialog({super.key});

  @override
  State<AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<AddSubscriptionDialog> {
  final _cubit = getIt<SubscriptionsCubit>();
  final _inputController = TextEditingController();
  final _nameController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _nameController.dispose();
    _inputFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await _cubit.addFromInput(
      _inputController.text,
      name: _nameController.text,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _submitting = false;
        _error = _cubit.state.errorMessage ?? 'Не удалось добавить';
      });
    }
  }

  InputDecoration _fieldDecoration({required String label, String? hint}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.gray0D0E11,
      labelStyle: const TextStyle(color: AppColors.grayA9BAC6),
      hintStyle: const TextStyle(color: AppColors.grayA9BAC6),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.green19FF90, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.gray181F25,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GestureDetector(
        onTap: () {
          if (!_inputFocusNode.hasFocus && !_nameFocusNode.hasFocus) {
            _inputFocusNode.requestFocus();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.green19FF90.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_link_rounded,
                      color: AppColors.green19FF90,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Новая подписка',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.grayA9BAC6,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _nameFocusNode.requestFocus(),
                style: const TextStyle(color: AppColors.white),
                decoration: _fieldDecoration(
                  label: 'Источник',
                  hint: 'https://…, vless://…, ss://… или JSON',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: AppColors.white),
                decoration: _fieldDecoration(label: 'Название (необязательно)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.redFF6A55),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green19FF90,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppColors.gray2E2E3A,
                    disabledForegroundColor: AppColors.grayA9BAC6,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
