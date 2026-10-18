import 'dart:io' show Platform;

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ad_block_store.dart';

/// Holds the current [AdBlockMode] for servers without their own routing.
/// Read at connect time by [RoutingPolicyGate]; a change takes effect on the
/// next connection.
///
/// [fullAllowed] is false on iOS: `category-ads-all` (plus the RU bypass
/// categories injected next to it) pushes the tunnel extension past its 50 MB
/// jetsam limit while xray builds the config, so the tunnel never comes up.
/// There the cubit only ever holds [AdBlockMode.off] or [AdBlockMode.basic].
@LazySingleton()
class AdBlockCubit extends Cubit<AdBlockMode> {
  AdBlockCubit({required AdBlockStore store, @ignoreParam bool? fullAllowed})
    : this._(store, fullAllowed ?? !Platform.isIOS);

  AdBlockCubit._(this._store, this.fullAllowed)
    : super(_allowed(_store.load(), fullAllowed));

  final AdBlockStore _store;

  /// Whether [AdBlockMode.full] can be picked; the UI offers the choice only
  /// then.
  final bool fullAllowed;

  static AdBlockMode _allowed(AdBlockMode mode, bool fullAllowed) =>
      mode == AdBlockMode.full && !fullAllowed ? AdBlockMode.basic : mode;

  /// The mode a plain on/off toggle turns on.
  AdBlockMode get _defaultWhenEnabled =>
      fullAllowed ? AdBlockMode.full : AdBlockMode.basic;

  Future<void> setMode(AdBlockMode mode) async {
    final allowed = _allowed(mode, fullAllowed);
    if (allowed == state) return;
    emit(allowed);
    await _store.save(allowed);
  }

  Future<void> setEnabled({required bool enabled}) =>
      setMode(enabled ? _defaultWhenEnabled : AdBlockMode.off);
}
