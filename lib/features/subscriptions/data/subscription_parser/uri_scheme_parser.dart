import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

// Parses subscription text lines of one URI scheme (vless://, ss://, ...).
abstract class UriSchemeParser {
  UriSchemeParser(this.talker);

  final Talker talker;

  List<String> get schemes;

  bool matches(String line) {
    final lower = line.trim().toLowerCase();
    return schemes.any((scheme) => lower.startsWith('$scheme://'));
  }

  VpnServer? parseOne(String line, String sourceId, int index);

  VpnServer? parseLine(String line, String sourceId, int index) {
    try {
      return parseOne(line.trim(), sourceId, index);
    } catch (e) {
      talker.warning('Parser: skipped a broken ${schemes.first}:// link -> $e');
      return null;
    }
  }

  List<VpnServer> parseLines(String text, String sourceId) {
    final result = <VpnServer>[];
    for (final (index, line) in subscriptionLines(text).indexed) {
      if (!matches(line)) continue;
      final server = parseLine(line, sourceId, index);
      if (server != null) result.add(server);
    }
    return result;
  }
}

Iterable<String> subscriptionLines(String text) =>
    text.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty);

// Normalizes a `type` query param to a network xray understands,
// null if the value is unknown.
String? normalizeNetwork(String? type) {
  switch ((type ?? 'tcp').trim().toLowerCase()) {
    case 'tcp':
    case 'raw':
      return 'tcp';
    case 'ws':
    case 'websocket':
      return 'ws';
    case 'grpc':
    case 'gun':
      return 'grpc';
    case 'httpupgrade':
      return 'httpupgrade';
    case 'xhttp':
    case 'splithttp':
      return 'xhttp';
    case 'kcp':
    case 'mkcp':
      return 'kcp';
    default:
      return null;
  }
}

bool isTruthy(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v == '1' || v == 'true';
}

// allowInsecure was removed from xray-core, both spellings show up in links.
void warnIfInsecureRequested(Talker talker, Map<String, String> query) {
  if (isTruthy(query['allowInsecure']) || isTruthy(query['insecure'])) {
    talker.warning(
      'Parser: allowInsecure was removed from xray-core, ignoring it, '
      'TLS verification stays on',
    );
  }
}

Map<String, String> rawQueryParameters(Uri uri) => parseQuery(uri.query);

Map<String, String> parseQuery(String query) {
  final result = <String, String>{};
  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    final key = eq < 0 ? pair : pair.substring(0, eq);
    final value = eq < 0 ? '' : pair.substring(eq + 1);
    try {
      result[Uri.decodeComponent(key)] = Uri.decodeComponent(value);
    } catch (_) {
      result[key] = value;
    }
  }
  return result;
}
