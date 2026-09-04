import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'base64_codec.dart';
import 'uri_scheme_parser.dart';
import 'xray_config_builder.dart';

class Hysteria2UriParser extends UriSchemeParser {
  final XrayConfigBuilder _configBuilder;

  Hysteria2UriParser(super.talker, this._configBuilder);

  @override
  List<String> get schemes => const ['hysteria2', 'hy2'];

  @override
  VpnServer? parseOne(String line, String sourceId, int index) {
    final uri = Uri.parse(line);
    final auth = Uri.decodeComponent(uri.userInfo);
    final address = uri.host;
    final port = uri.port;

    if (auth.isEmpty || address.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    final query = rawQueryParameters(uri);
    warnIfInsecureRequested(talker, query);
    // salamander is the only obfs xray has a finalmask for
    final obfs = (query['obfs'] ?? '').trim().toLowerCase();
    if (obfs.isNotEmpty && obfs != 'salamander') {
      talker.warning('Parser: unsupported hysteria2 obfs=$obfs, ignoring it');
    }
    final obfsPassword = obfs == 'salamander'
        ? (query['obfs-password'] ?? '')
        : '';

    final rawRemarks = uri.fragment;
    final title = rawRemarks.isNotEmpty
        ? Uri.decodeComponent(rawRemarks)
        : '$address:$port';

    final configJson = _configBuilder.buildHysteria2(
      password: auth,
      address: address,
      port: port,
      title: title,
      sni: query['sni'] ?? '',
      pinSHA256: _pinToHex(query['pinSHA256'] ?? ''),
      obfsPassword: obfsPassword,
      mport: query['mport'] ?? '',
    );

    return VpnServer(
      id: '$address:$port:$auth:#$index',
      subscriptionId: sourceId,
      title: title,
      countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
      configJson: configJson,
    );
  }

  // share links carry the pinned certificate hash as base64, xray wants hex
  String _pinToHex(String pin) {
    if (pin.isEmpty) return '';
    final bytes = tryDecodeBase64Bytes(pin);
    if (bytes == null || bytes.length != 32) return pin;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
