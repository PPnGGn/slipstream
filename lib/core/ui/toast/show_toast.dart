import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';

/// Shows a toast from anywhere in the UI. [subtitle] is the small caps line
/// under the title (a detail, never a sentence); skip it for plain messages.
void showToast(
  String title, {
  String? subtitle,
  ToastKind kind = ToastKind.success,
}) => getIt<ToastCubit>().show(title, subtitle: subtitle, kind: kind);

/// The same, for wording decided elsewhere (see [ToastSpec]).
void showToastSpec(ToastSpec spec) => getIt<ToastCubit>().showSpec(spec);
