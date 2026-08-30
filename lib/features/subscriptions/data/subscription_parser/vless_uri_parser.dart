import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'xray_config_builder.dart';

class VlessUriParser {
  final Talker _talker;
  final XrayConfigBuilder _configBuilder;

  VlessUriParser(this._talker, this._configBuilder);

  bool isVless(String s) => s.trim().toLowerCase().startsWith('vless://');

  List<VpnServer> parseLines(String text, String sourceId) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty);
    final List<VpnServer> result = [];

    for (final (index, line) in lines.indexed) {
      if (!isVless(line)) continue;

      try {
        final uri = Uri.parse(line.trim());
        final uuid = uri.userInfo;
        final address = uri.host;
        final port = uri.port;

        if (uuid.isEmpty || address.isEmpty || port <= 0 || port > 65535) {
          continue;
        }

        final query = uri.queryParameters;
        final sni = query['sni'] ?? '';
        final pbk = query['pbk'] ?? '';
        final sid = query['sid'] ?? '';
        final fp = query['fp'] ?? 'chrome';
        final flow = query['flow'] ?? '';

        final rawRemarks = uri.fragment;
        final title = rawRemarks.isNotEmpty
            ? Uri.decodeComponent(rawRemarks)
            : '$address:$port';

        final configJson = _configBuilder.buildVlessReality(
          uuid: uuid,
          address: address,
          port: port,
          sni: sni,
          pbk: pbk,
          sid: sid,
          fp: fp,
          flow: flow,
          title: title,
        );

        result.add(
          VpnServer(
            id: '$address:$port:$uuid:#$index',
            subscriptionId: sourceId,
            title: title,
            countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
            configJson: configJson,
          ),
        );
      } catch (e) {
        _talker.warning('Parser: skipped a broken link -> $e');
      }
    }
    return result;
  }
}
