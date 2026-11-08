import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Texts of the DNS page, as pure functions: the page only draws what these
/// say, so they can be tested without a widget. Names of services (Cloudflare,
/// Google, Yandex) are not translated.

String remoteDnsTitle(AppLocalizations l10n, RemoteDns remote) =>
    switch (remote) {
      RemoteDns.cloudflare => 'Cloudflare DoH',
      RemoteDns.google => 'Google DoH',
      RemoteDns.xray => l10n.dnsXrayTitle,
    };

/// What the row shows under the title: the address the config really uses, so
/// the page never says one thing while the tunnel does another.
String remoteDnsSubtitle(AppLocalizations l10n, RemoteDns remote) =>
    switch (remote) {
      RemoteDns.cloudflare || RemoteDns.google => remote.address,
      RemoteDns.xray => l10n.dnsXraySubtitle,
    };

String directDnsTitle(AppLocalizations l10n, DirectDns direct) =>
    switch (direct) {
      DirectDns.yandex => 'Yandex DNS',
      DirectDns.system => l10n.dnsSystemTitle,
    };

String directDnsSubtitle(AppLocalizations l10n, DirectDns direct) =>
    switch (direct) {
      DirectDns.yandex => direct.address,
      DirectDns.system => l10n.dnsSystemSubtitle,
    };

/// The direct resolver is asked only for Russian names, which exist as a
/// separate case only while the RU bypass is on.
bool directDnsActive(RuBypassMode mode) => mode == RuBypassMode.bypassRu;

/// Why the direct section is greyed out; null while it is live.
String? directDnsHint(AppLocalizations l10n, {required bool active}) =>
    active ? null : l10n.dnsDirectHint;

String fakeDnsSubtitle(AppLocalizations l10n, {required bool enabled}) =>
    enabled ? l10n.fakeDnsOn : l10n.fakeDnsOff;

/// The value of the DNS row in Settings: the remote resolver, and Fake DNS if
/// on. The direct resolver is left out: it matters only with the RU bypass,
/// which has its own row.
String dnsSummary(AppLocalizations l10n, DnsSettings settings) => [
  remoteDnsTitle(l10n, settings.remote),
  if (settings.fakeDns) 'Fake DNS',
].join(' · ');
