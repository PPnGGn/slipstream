import 'package:flutter/foundation.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';

/// All the choices of the DNS page, as one value. The defaults are what the
/// app did before the page existed, so an update changes nothing by itself.
@immutable
class DnsSettings {
  const DnsSettings({
    this.remote = RemoteDns.google,
    this.direct = DirectDns.yandex,
    this.fakeDns = false,
  });

  /// Resolver for names the tunnel looks up itself, reached through the VPN.
  final RemoteDns remote;

  /// Resolver for names whose traffic bypasses the VPN (RU bypass only).
  final DirectDns direct;

  /// Whether apps get made-up addresses at once instead of waiting for a real
  /// answer. Android only.
  final bool fakeDns;

  DnsSettings copyWith({RemoteDns? remote, DirectDns? direct, bool? fakeDns}) =>
      DnsSettings(
        remote: remote ?? this.remote,
        direct: direct ?? this.direct,
        fakeDns: fakeDns ?? this.fakeDns,
      );

  @override
  bool operator ==(Object other) =>
      other is DnsSettings &&
      other.remote == remote &&
      other.direct == direct &&
      other.fakeDns == fakeDns;

  @override
  int get hashCode => Object.hash(remote, direct, fakeDns);

  @override
  String toString() =>
      'DnsSettings(remote: ${remote.name}, direct: ${direct.name}, '
      'fakeDns: $fakeDns)';
}
