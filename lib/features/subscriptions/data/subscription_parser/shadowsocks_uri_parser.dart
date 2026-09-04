import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'base64_codec.dart';
import 'uri_scheme_parser.dart';
import 'xray_config_builder.dart';

class ShadowsocksUriParser extends UriSchemeParser {
  final XrayConfigBuilder _configBuilder;

  ShadowsocksUriParser(super.talker, this._configBuilder);

  @override
  List<String> get schemes => const ['ss'];

  @override
  VpnServer? parseOne(String line, String sourceId, int index) {
    var body = line.substring('ss://'.length);

    String title = '';
    final hashIndex = body.indexOf('#');
    if (hashIndex >= 0) {
      final rawTag = body.substring(hashIndex + 1);
      if (rawTag.isNotEmpty) title = Uri.decodeComponent(rawTag);
      body = body.substring(0, hashIndex);
    }

    String method;
    String password;
    String host;
    int port;
    var query = const <String, String>{};

    final atIndex = body.lastIndexOf('@');
    if (atIndex >= 0) {
      // SIP002: base64url(method:password)@host:port[/?type=ws&plugin=...]
      final creds = _decodeUserInfo(body.substring(0, atIndex));
      if (creds == null) return null;
      (method, password) = creds;

      var hostPart = body.substring(atIndex + 1);
      final cut = hostPart.indexOf(RegExp(r'[/?]'));
      if (cut >= 0) {
        final tail = hostPart.substring(cut);
        final questionMark = tail.indexOf('?');
        if (questionMark >= 0) {
          query = parseQuery(tail.substring(questionMark + 1));
        }
        hostPart = hostPart.substring(0, cut);
      }

      final hp = _splitHostPort(hostPart);
      if (hp == null) return null;
      (host, port) = hp;
    } else {
      // Legacy: base64(method:password@host:port)
      final decoded = tryDecodeBase64(body);
      if (decoded == null) return null;
      final at = decoded.lastIndexOf('@');
      if (at < 0) return null;
      final creds = _splitOnFirstColon(decoded.substring(0, at));
      if (creds == null) return null;
      (method, password) = creds;

      final hp = _splitHostPort(decoded.substring(at + 1));
      if (hp == null) return null;
      (host, port) = hp;
    }

    if (method.isEmpty || host.isEmpty) return null;
    if (title.isEmpty) title = '$host:$port';

    final StreamOptions stream;
    final plugin = (query['plugin'] ?? '').trim();
    if (plugin.isNotEmpty) {
      final fromPlugin = _streamFromPlugin(plugin);
      if (fromPlugin == null) {
        talker.warning(
          'Parser: skipped an ss link with an unsupported plugin=$plugin',
        );
        return null;
      }
      stream = fromPlugin;
    } else {
      final network = normalizeNetwork(query['type']);
      if (network == null) {
        talker.warning(
          'Parser: skipped an ss link with unknown type=${query['type']}',
        );
        return null;
      }
      warnIfInsecureRequested(talker, query);
      stream = StreamOptions(
        network: network,
        security: _security(query),
        sni: query['sni'] ?? '',
        fp: query['fp'] ?? '',
        alpn: query['alpn'] ?? '',
        path: query['path'] ?? '',
        host: query['host'] ?? '',
        serviceName: query['serviceName'] ?? '',
        authority: query['authority'] ?? '',
        headerType: query['headerType'] ?? '',
        seed: query['seed'] ?? '',
        mode: query['mode'] ?? '',
      );
    }

    final configJson = _configBuilder.buildShadowsocks(
      method: method,
      password: password,
      address: host,
      port: port,
      title: title,
      stream: stream,
    );

    return VpnServer(
      id: '$host:$port:$method:#$index',
      subscriptionId: sourceId,
      title: title,
      countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
      configJson: configJson,
    );
  }

  // SIP003 plugins are separate processes xray cannot run, but the two common
  // ones only wrap the traffic in a transport xray has natively.
  StreamOptions? _streamFromPlugin(String plugin) {
    final parts = plugin.split(';');
    final options = <String, String>{};
    for (final part in parts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq < 0) {
        options[part.trim()] = '';
      } else {
        options[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
      }
    }

    switch (parts.first.trim()) {
      case 'v2ray-plugin':
      case 'xray-plugin':
        final mode = options['mode'] ?? 'websocket';
        if (mode != 'websocket') return null;
        final host = options['host'] ?? '';
        return StreamOptions(
          network: 'ws',
          security: options.containsKey('tls') ? 'tls' : 'none',
          sni: host,
          path: options['path'] ?? '',
          host: host,
        );
      case 'obfs-local':
      case 'simple-obfs':
        if (options['obfs'] != 'http') return null;
        return StreamOptions(
          network: 'tcp',
          headerType: 'http',
          host: options['obfs-host'] ?? '',
          path: options['obfs-uri'] ?? '',
        );
      default:
        return null;
    }
  }

  String _security(Map<String, String> query) {
    return switch ((query['security'] ?? '').trim().toLowerCase()) {
      'tls' => 'tls',
      _ => 'none',
    };
  }

  (String, String)? _decodeUserInfo(String userInfo) {
    final decoded = tryDecodeBase64(userInfo) ?? Uri.decodeComponent(userInfo);
    return _splitOnFirstColon(decoded);
  }

  (String, String)? _splitOnFirstColon(String s) {
    final colon = s.indexOf(':');
    if (colon < 0) return null;
    return (s.substring(0, colon), s.substring(colon + 1));
  }

  (String, int)? _splitHostPort(String hostPort) {
    String host;
    String portStr;
    if (hostPort.startsWith('[')) {
      final close = hostPort.indexOf(']');
      if (close < 0 ||
          close + 1 >= hostPort.length ||
          hostPort[close + 1] != ':') {
        return null;
      }
      host = hostPort.substring(1, close);
      portStr = hostPort.substring(close + 2);
    } else {
      final colon = hostPort.lastIndexOf(':');
      if (colon < 0) return null;
      host = hostPort.substring(0, colon);
      portStr = hostPort.substring(colon + 1);
    }
    final port = int.tryParse(portStr);
    if (host.isEmpty || port == null || port <= 0 || port > 65535) return null;
    return (host, port);
  }
}
