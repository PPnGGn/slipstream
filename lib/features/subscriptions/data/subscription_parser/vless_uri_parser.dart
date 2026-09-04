import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'uri_scheme_parser.dart';
import 'xray_config_builder.dart';

class VlessUriParser extends UriSchemeParser {
  final XrayConfigBuilder _configBuilder;

  VlessUriParser(super.talker, this._configBuilder);

  @override
  List<String> get schemes => const ['vless'];

  @override
  VpnServer? parseOne(String line, String sourceId, int index) {
    final uri = Uri.parse(line);
    final uuid = uri.userInfo;
    final address = uri.host;
    final port = uri.port;

    if (uuid.isEmpty || address.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    final query = rawQueryParameters(uri);
    final network = normalizeNetwork(query['type']);
    if (network == null) {
      talker.warning(
        'Parser: skipped a vless link with unknown type=${query['type']}',
      );
      return null;
    }
    final security = _security(query);
    if (security == null) {
      talker.warning(
        'Parser: skipped a vless link with unknown security=${query['security']}',
      );
      return null;
    }
    if (security == 'reality' && (query['pbk'] ?? '').isEmpty) {
      talker.warning('Parser: skipped a reality vless link with no pbk');
      return null;
    }
    warnIfInsecureRequested(talker, query);

    final rawRemarks = uri.fragment;
    final title = rawRemarks.isNotEmpty
        ? Uri.decodeComponent(rawRemarks)
        : '$address:$port';

    final configJson = _configBuilder.buildVless(
      uuid: uuid,
      address: address,
      port: port,
      title: title,
      flow: query['flow'] ?? '',
      encryption: query['encryption'] ?? '',
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
        extra: decodeExtra(talker, query['extra']),
      ),
    );

    return VpnServer(
      id: '$address:$port:$uuid:#$index',
      subscriptionId: sourceId,
      title: title,
      countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
      configJson: configJson,
    );
  }

  // Explicit `security` wins; otherwise guess from the params that are present.
  String? _security(Map<String, String> query) {
    final raw = (query['security'] ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      if ((query['pbk'] ?? '').isNotEmpty) return 'reality';
      if ((query['sni'] ?? '').isNotEmpty) return 'tls';
      return 'none';
    }
    return switch (raw) {
      'reality' => 'reality',
      'tls' => 'tls',
      'none' => 'none',
      _ => null,
    };
  }
}
