import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/dns_settings_store.dart';
import 'package:slipstream/features/dns/data/dns_support.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';

/// Holds the current [DnsSettings]. Read at connect time (VpnRepository.start)
/// and handed to RoutingPolicyGate; a change takes effect on the next
/// connection, not while the tunnel runs.
///
/// [fakeDnsAllowed] is false off Android: there the cubit only ever holds
/// `fakeDns == false`, whatever the store says, and the page hides the row.
@LazySingleton()
class DnsCubit extends Cubit<DnsSettings> {
  DnsCubit({required DnsSettingsStore store, @ignoreParam bool? fakeDnsAllowed})
    : this._(
        store,
        fakeDnsAllowed ?? isFakeDnsSupported(defaultTargetPlatform),
      );

  DnsCubit._(this._store, this.fakeDnsAllowed)
    : super(_allowed(_store.load(), fakeDnsAllowed));

  final DnsSettingsStore _store;

  /// Whether Fake DNS can be turned on; the page offers the row only then.
  final bool fakeDnsAllowed;

  static DnsSettings _allowed(DnsSettings settings, bool fakeDnsAllowed) =>
      settings.fakeDns && !fakeDnsAllowed
      ? settings.copyWith(fakeDns: false)
      : settings;

  Future<void> setRemote(RemoteDns remote) =>
      _apply(state.copyWith(remote: remote));

  Future<void> setDirect(DirectDns direct) =>
      _apply(state.copyWith(direct: direct));

  Future<void> setFakeDns({required bool enabled}) =>
      _apply(state.copyWith(fakeDns: enabled));

  Future<void> _apply(DnsSettings next) async {
    final allowed = _allowed(next, fakeDnsAllowed);
    if (allowed == state) return;
    emit(allowed);
    await _store.save(allowed);
  }
}
