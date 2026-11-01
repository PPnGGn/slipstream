import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/security/data/ipv6_store.dart';

/// State: whether the tunnel carries IPv6. The value reaches the VPN service
/// with the next connect (see VpnRepository.start), not while it runs.
@LazySingleton()
class Ipv6Cubit extends Cubit<bool> {
  Ipv6Cubit({required Ipv6Store store}) : _store = store, super(store.load());

  final Ipv6Store _store;

  Future<void> setEnabled({required bool enabled}) async {
    if (enabled == state) return;
    emit(enabled);
    await _store.save(enabled: enabled);
  }
}
