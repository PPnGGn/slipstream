import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/models/result.dart';
import 'base64_codec.dart';
import 'custom_json_parser.dart';
import 'hysteria2_uri_parser.dart';
import 'shadowsocks_uri_parser.dart';
import 'subscription_fetcher.dart';
import 'trojan_uri_parser.dart';
import 'uri_scheme_parser.dart';
import 'vless_uri_parser.dart';
import 'vmess_uri_parser.dart';
import 'xray_config_builder.dart';

class ParsedSubscription {
  ParsedSubscription({
    required this.servers,
    this.suggestedName,
    this.announce,
    this.expiresAt,
    this.updateIntervalHours,
    this.usedBytes,
    this.dataLimitBytes,
  });

  final List<VpnServer> servers;
  final String? suggestedName;
  final String? announce;
  final DateTime? expiresAt;
  final int? updateIntervalHours;
  final int? usedBytes;
  final int? dataLimitBytes;
}

@lazySingleton
class SubscriptionParserService {
  final Talker _talker;
  final SubscriptionFetcher _fetcher;
  final CustomJsonParser _customJsonParser;
  final List<UriSchemeParser> _uriParsers;

  SubscriptionParserService(
    Talker talker, {
    @ignoreParam SubscriptionFetcher? fetcher,
  }) : _talker = talker,
       _fetcher = fetcher ?? SubscriptionFetcher(),
       _customJsonParser = CustomJsonParser(talker),
       _uriParsers = _buildUriParsers(talker);

  static List<UriSchemeParser> _buildUriParsers(Talker talker) {
    final builder = XrayConfigBuilder();
    return [
      VlessUriParser(talker, builder),
      VmessUriParser(talker, builder),
      TrojanUriParser(talker, builder),
      Hysteria2UriParser(talker, builder),
      ShadowsocksUriParser(talker, builder),
    ];
  }

  Future<Result<ParsedSubscription>> parseFromInput(String input) async {
    try {
      final cleanInput = input.trim();
      final List<VpnServer> servers = [];
      String textToParse = cleanInput;
      SubscriptionResponse? response;

      final lowerInput = cleanInput.toLowerCase();
      if (lowerInput.startsWith('http://') ||
          lowerInput.startsWith('https://')) {
        _talker.debug('Parser: found a URL, fetching...');
        response = await _fetcher.fetch(cleanInput);
        textToParse = response.body;
      } else if (!_isDirectLink(cleanInput) &&
          !cleanInput.startsWith('[') &&
          !cleanInput.startsWith('{') &&
          tryDecodeBase64(cleanInput) == null) {
        return const Failure(
          'Unknown input format. Expected an http(s) link, vless://, '
          'vmess://, trojan://, hysteria2://, ss:// or a raw JSON config',
        );
      }

      final trimmed = textToParse.trim();
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        _talker.debug('Parser: found a raw JSON config');
        servers.addAll(_customJsonParser.parse(textToParse, cleanInput));
      } else {
        String decoded = trimmed;
        if (_isDirectLink(trimmed)) {
          _talker.debug('Parser: found direct links (URI)');
        } else {
          final fromBase64 = tryDecodeBase64(trimmed);
          if (fromBase64 == null) {
            _talker.debug('Parser: not base64, parsing as plain text');
          } else {
            _talker.debug('Parser: found base64, decoding...');
            decoded = fromBase64;
          }
        }
        servers.addAll(_parseLinks(decoded, cleanInput));
      }

      if (servers.isEmpty) {
        return const Failure('No supported servers were found in the response');
      }

      _talker.info('Parser: successfully parsed ${servers.length} server(s)');
      return Success(
        ParsedSubscription(
          servers: servers,
          suggestedName: response?.profileTitle,
          announce: response?.announce,
          expiresAt: response?.expiresAt,
          updateIntervalHours: response?.updateIntervalHours,
          usedBytes: response?.usedBytes,
          dataLimitBytes: response?.dataLimitBytes,
        ),
      );
    } catch (e, st) {
      _talker.handle(e, st, 'Parser: unhandled error while processing');
      return Failure('Failed to process the data: $e');
    }
  }

  List<VpnServer> _parseLinks(String text, String sourceId) {
    final servers = <VpnServer>[];
    var unsupported = 0;

    for (final (index, line) in subscriptionLines(text).indexed) {
      final parser = _uriParsers.firstWhereOrNull((p) => p.matches(line));
      if (parser == null) {
        unsupported++;
        continue;
      }
      final server = parser.parseLine(line, sourceId, index);
      if (server != null) servers.add(server);
    }

    if (unsupported > 0) {
      _talker.warning(
        'Parser: ignored $unsupported line(s) with an unsupported scheme',
      );
    }
    return servers;
  }

  bool _isDirectLink(String s) => _uriParsers.any((p) => p.matches(s));
}
