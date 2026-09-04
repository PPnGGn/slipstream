import 'dart:convert';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'base64_codec.dart';
import 'uri_scheme_parser.dart';
import 'xray_config_builder.dart';

class VmessUriParser extends UriSchemeParser {
  final XrayConfigBuilder _configBuilder;

  VmessUriParser(super.talker, this._configBuilder);

  @override
  List<String> get schemes => const ['vmess'];

  // vmess:// links carry a base64-encoded JSON object (v2rayN format).
  @override
  VpnServer? parseOne(String line, String sourceId, int index) {
    final decoded = tryDecodeBase64(line.substring('vmess://'.length));
    if (decoded == null) return null;

    final json = jsonDecode(decoded);
    if (json is! Map<String, dynamic>) return null;

    final address = (json['add'] as String? ?? '').trim();
    final port = int.tryParse('${json['port']}') ?? 0;
    final uuid = (json['id'] as String? ?? '').trim();
    if (address.isEmpty || uuid.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    final network = normalizeNetwork(json['net'] as String?);
    if (network == null) {
      talker.warning(
        'Parser: skipped a vmess link with unknown net=${json['net']}',
      );
      return null;
    }

    var title = (json['ps'] as String? ?? '').trim();
    if (title.isEmpty) title = '$address:$port';

    // in the v2rayN format `path` doubles as grpc serviceName / kcp seed
    final path = (json['path'] as String? ?? '').trim();
    final security = (json['tls'] as String? ?? '').trim().toLowerCase();

    final configJson = _configBuilder.buildVmess(
      uuid: uuid,
      alterId: int.tryParse('${json['aid']}') ?? 0,
      security: (json['scy'] as String? ?? '').trim(),
      address: address,
      port: port,
      title: title,
      stream: StreamOptions(
        network: network,
        security: security == 'tls' ? 'tls' : 'none',
        sni: (json['sni'] as String? ?? '').trim(),
        fp: (json['fp'] as String? ?? '').trim(),
        alpn: (json['alpn'] as String? ?? '').trim(),
        path: network == 'grpc' || network == 'kcp' ? '' : path,
        host: (json['host'] as String? ?? '').trim(),
        serviceName: network == 'grpc' ? path : '',
        headerType: (json['type'] as String? ?? '').trim(),
        seed: network == 'kcp' ? path : '',
        mode: (json['mode'] as String? ?? '').trim(),
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
}
