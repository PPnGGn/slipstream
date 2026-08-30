import 'dart:convert';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'xray_config_builder.dart';

class ShadowsocksUriParser {
  final Talker _talker;
  final XrayConfigBuilder _configBuilder;

  ShadowsocksUriParser(this._talker, this._configBuilder);

  bool isShadowsocks(String s) => s.trim().toLowerCase().startsWith('ss://');

  List<VpnServer> parseLines(String text, String sourceId) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty);
    final result = <VpnServer>[];

    for (final (index, line) in lines.indexed) {
      if (!isShadowsocks(line)) continue;
      try {
        final server = _parseOne(line.trim(), sourceId, index);
        if (server != null) result.add(server);
      } catch (e) {
        _talker.warning('Parser: skipped a broken ss:// link -> $e');
      }
    }
    return result;
  }

  VpnServer? _parseOne(String line, String sourceId, int index) {
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

    final atIndex = body.lastIndexOf('@');
    if (atIndex >= 0) {
      // SIP002: base64url(method:password)@host:port[/?plugin=...]
      final creds = _decodeUserInfo(body.substring(0, atIndex));
      if (creds == null) return null;
      (method, password) = creds;

      var hostPart = body.substring(atIndex + 1);
      // no plugin support, cut off the path/query if there is one
      final cut = hostPart.indexOf(RegExp(r'[/?]'));
      if (cut >= 0) hostPart = hostPart.substring(0, cut);

      final hp = _splitHostPort(hostPart);
      if (hp == null) return null;
      (host, port) = hp;
    } else {
      // Legacy: base64(method:password@host:port)
      final decoded = _tryBase64(body);
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

    final configJson = _configBuilder.buildShadowsocks(
      method: method,
      password: password,
      address: host,
      port: port,
      title: title,
    );

    return VpnServer(
      id: '$host:$port:$method:#$index',
      subscriptionId: sourceId,
      title: title,
      countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
      configJson: configJson,
    );
  }

  (String, String)? _decodeUserInfo(String userInfo) {
    final decoded = _tryBase64(userInfo) ?? Uri.decodeComponent(userInfo);
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

  // Decodes a (possibly unpadded, standard or URL-safe) Base64 string, or null.
  String? _tryBase64(String s) {
    var normalized = s.replaceAll(RegExp(r'\s+'), '');
    final padding = normalized.length % 4;
    if (padding != 0) normalized += '=' * (4 - padding);
    try {
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      try {
        return utf8.decode(base64Url.decode(normalized));
      } catch (_) {
        return null;
      }
    }
  }
}
