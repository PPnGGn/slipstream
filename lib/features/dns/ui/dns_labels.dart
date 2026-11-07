import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

/// Texts of the DNS page, as pure functions: the page only draws what these
/// say, so they can be tested without a widget.

String remoteDnsTitle(RemoteDns remote) => switch (remote) {
  RemoteDns.cloudflare => 'Cloudflare DoH',
  RemoteDns.google => 'Google DoH',
  RemoteDns.xray => 'Xray built-in',
};

/// What the row shows under the title: the address the config really uses, so
/// the page never says one thing while the tunnel does another.
String remoteDnsSubtitle(RemoteDns remote) => switch (remote) {
  RemoteDns.cloudflare || RemoteDns.google => remote.address,
  RemoteDns.xray => 'UDP 1.1.1.1:53 VIA TUNNEL',
};

String directDnsTitle(DirectDns direct) => switch (direct) {
  DirectDns.yandex => 'Yandex DNS',
  DirectDns.system => 'System resolver',
};

String directDnsSubtitle(DirectDns direct) => switch (direct) {
  DirectDns.yandex => direct.address,
  DirectDns.system => 'The phone\'s own DNS, usually the operator\'s',
};

/// The direct resolver is asked only for Russian names, which exist as a
/// separate case only while the RU bypass is on.
bool directDnsActive(RuBypassMode mode) => mode == RuBypassMode.bypassRu;

/// Why the direct section is greyed out; null while it is live.
String? directDnsHint({required bool active}) =>
    active ? null : 'Used only while the RU bypass is on (Routing).';

String fakeDnsSubtitle({required bool enabled}) => enabled
    ? 'Apps get made-up addresses at once, faster first connect'
    : 'Off · apps wait for a real answer';

/// The value of the DNS row in Settings: the remote resolver, and Fake DNS if
/// on. The direct resolver is left out: it matters only with the RU bypass,
/// which has its own row.
String dnsSummary(DnsSettings settings) => [
  remoteDnsTitle(settings.remote),
  if (settings.fakeDns) 'Fake DNS',
].join(' · ');
