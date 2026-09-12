import 'dart:io' show Platform;

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ad_block_store.dart';

/// Holds the current [AdBlockMode] for servers without their own routing.
/// Read at connect time by [RoutingPolicyGate]; a change takes effect on the
/// next connection.
@LazySingleton()
class AdBlockCubit extends Cubit<AdBlockMode> {
  AdBlockCubit({required AdBlockStore store})
    : _store = store,
      super(store.load());

  final AdBlockStore _store;

  /// The mode a plain on/off toggle turns on: the lighter [AdBlockMode.basic]
  /// on iOS, where `category-ads-all`'s ~34 MB matcher risks a jetsam kill in
  /// the tunnel extension; [AdBlockMode.full] elsewhere.
  static AdBlockMode get defaultWhenEnabled =>
      Platform.isIOS ? AdBlockMode.basic : AdBlockMode.full;

  Future<void> setMode(AdBlockMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _store.save(mode);
  }

  Future<void> setEnabled({required bool enabled}) =>
      setMode(enabled ? defaultWhenEnabled : AdBlockMode.off);
}
