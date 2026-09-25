import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/ping/domain/contracts/host_resolver.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

@LazySingleton(as: HostResolver)
class DnsHostResolver implements HostResolver {
  const DnsHostResolver();

  @override
  Future<List<InternetAddress>> resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return [literal];

    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(milliseconds: dnsTimeoutMs));
      // IPv4 first: on mobile networks IPv6 routes are more often
      // broken or blackholed than v4, and a probe that picks a broken
      // v6 address first would misreport a reachable server as dead.
      return [...addresses]..sort(
        (a, b) => a.type == b.type
            ? 0
            : (a.type == InternetAddressType.IPv4 ? -1 : 1),
      );
    } on Object {
      return const [];
    }
  }
}
