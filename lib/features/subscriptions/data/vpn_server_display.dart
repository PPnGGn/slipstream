import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';

extension VpnServerDisplay on VpnServer {
  bool get _hasInlineFlag => startsWithFlagEmoji(title);

  String get flagEmoji => _hasInlineFlag
      ? String.fromCharCodes(title.runes.take(2))
      : (countryCode == unknownCountryCode ? '🏳️' : countryFlag(countryCode));

  /// Title without the leading flag emoji, so the tile doesn't double it up.
  String get displayTitle => _hasInlineFlag
      ? String.fromCharCodes(title.runes.skip(2)).trimLeft()
      : title;

  XrayServerMeta get meta => readXrayServerMeta(configJson);
}
