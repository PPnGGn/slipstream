import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';

@lazySingleton
class ToastCubit extends Cubit<ToastMessage?> {
  ToastCubit() : super(null);

  Timer? _timer;
  int _nextId = 0;

  /// Replaces whatever is showing: there is never a queue, a newer message
  /// matters more than an older one that has not been read yet.
  void show(
    String title, {
    String? subtitle,
    ToastKind kind = ToastKind.success,
  }) {
    _timer?.cancel();
    final message = ToastMessage(
      id: _nextId++,
      title: title,
      kind: kind,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
    );
    emit(message);
    _timer = Timer(message.duration, dismiss);
  }

  void showSpec(ToastSpec spec) =>
      show(spec.title, subtitle: spec.subtitle, kind: spec.kind);

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    emit(null);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
