import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';

// Keyed on VpnServer identity (not value equality) on purpose: the
// same server instance is what every list rebuild reuses (subscription
// state doesn't change just because the ping badge or connection card
// rebuilt), so this is a correct and cheap cache. `meta` decodes
// configJson as JSON, and `ServerTile`/`PingBadge` read it on every
// build — without caching, a ping run's rapid entry patches (each one
// rebuilding a BlocBuilder that spans the whole server list) made every
// row re-parse its JSON dozens of times a second, which is what caused
// the multi-second UI freeze right when a ping run started.
final _metaCache = Expando<XrayServerMeta>('vpnServerMeta');

extension VpnServerDisplay on VpnServer {
  bool get _hasInlineFlag => startsWithFlagEmoji(title);

  String get flagEmoji => _hasInlineFlag
      ? String.fromCharCodes(title.runes.take(2))
      : (countryCode == unknownCountryCode ? '🏳️' : countryFlag(countryCode));

  /// Title without the leading flag emoji, so the tile doesn't double it up.
  String get displayTitle => _hasInlineFlag
      ? String.fromCharCodes(title.runes.skip(2)).trimLeft()
      : title;

  XrayServerMeta get meta =>
      _metaCache[this] ??= readXrayServerMeta(configJson);
}
