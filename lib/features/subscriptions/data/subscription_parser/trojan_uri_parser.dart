import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'uri_scheme_parser.dart';
import 'xray_config_builder.dart';

class TrojanUriParser extends UriSchemeParser {
  final XrayConfigBuilder _configBuilder;

  TrojanUriParser(super.talker, this._configBuilder);

  @override
  List<String> get schemes => const ['trojan'];

  @override
  VpnServer? parseOne(String line, String sourceId, int index) {
    final uri = Uri.parse(line);
    final password = Uri.decodeComponent(uri.userInfo);
    final address = uri.host;
    final port = uri.port;

    if (password.isEmpty || address.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    final query = rawQueryParameters(uri);
    final network = normalizeNetwork(query['type']);
    if (network == null) {
      talker.warning(
        'Parser: skipped a trojan link with unknown type=${query['type']}',
      );
      return null;
    }
    final security = _security(query);
    if (security == 'reality' && (query['pbk'] ?? '').isEmpty) {
      talker.warning('Parser: skipped a reality trojan link with no pbk');
      return null;
    }
    warnIfInsecureRequested(talker, query);

    final rawRemarks = uri.fragment;
    final title = rawRemarks.isNotEmpty
        ? Uri.decodeComponent(rawRemarks)
        : '$address:$port';

    final configJson = _configBuilder.buildTrojan(
      password: password,
      address: address,
      port: port,
      title: title,
      stream: StreamOptions(
        network: network,
        security: security,
        sni: query['sni'] ?? '',
        fp: query['fp'] ?? '',
        alpn: query['alpn'] ?? '',
        pbk: query['pbk'] ?? '',
        sid: query['sid'] ?? '',
        spx: query['spx'] ?? '',
        path: query['path'] ?? '',
        host: query['host'] ?? '',
        serviceName: query['serviceName'] ?? '',
        authority: query['authority'] ?? '',
        headerType: query['headerType'] ?? '',
        seed: query['seed'] ?? '',
        mode: query['mode'] ?? '',
      ),
    );

    return VpnServer(
      id: '$address:$port:$password:#$index',
      subscriptionId: sourceId,
      title: title,
      countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
      configJson: configJson,
    );
  }

  // trojan is tls by design, plain `none` is rare but valid
  String _security(Map<String, String> query) {
    return switch ((query['security'] ?? '').trim().toLowerCase()) {
      'none' => 'none',
      'reality' => 'reality',
      _ => 'tls',
    };
  }
}
