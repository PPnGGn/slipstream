import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/utils/formatters.dart';

class CustomJsonParser {
  final Talker _talker;
  CustomJsonParser(this._talker);

  List<VpnServer> parse(String rawJson, String sourceId) {
    final decoded = jsonDecode(rawJson);
    final list = decoded is List ? decoded : [decoded];
    final List<VpnServer> result = [];

    for (final (index, item) in list.indexed) {
      try {
        final config = item as Map<String, dynamic>;
        final title = config['remarks'] as String? ?? 'Unknown Server';
        final outbounds = config['outbounds'] as List<dynamic>;

        final proxyOutbound = outbounds
            .cast<Map<String, dynamic>>()
            .firstWhereOrNull((o) {
              final tag = o['tag'] as String? ?? '';
              return tag == 'proxy' || tag.startsWith('proxy-');
            });

        if (proxyOutbound == null) continue;

        final normalizedProxy = _normalizeOutboundSettings(proxyOutbound);
        final settings = normalizedProxy['settings'] as Map<String, dynamic>;
        final addressPort = _extractAddressPort(settings);
        if (addressPort == null) continue;

        final address = addressPort.$1;
        final port = addressPort.$2;
        final uuid = addressPort.$3;

        final baseId = uuid.isNotEmpty
            ? '$address:$port:$uuid'
            : '$address:$port';

        result.add(
          VpnServer(
            id: '$baseId:#$index',
            subscriptionId: sourceId,
            title: title,
            countryCode: countryCodeFromFlag(title) ?? unknownCountryCode,
            configJson: jsonEncode(
              _buildServerConfig(config, proxyOutbound, normalizedProxy),
            ),
          ),
        );
      } catch (e) {
        _talker.warning('Parser: skipped a broken JSON entry -> $e');
      }
    }
    return result;
  }

  Map<String, dynamic> _normalizeOutboundSettings(
    Map<String, dynamic> outbound,
  ) {
    final settings = outbound['settings'] as Map<String, dynamic>?;
    if (settings == null || !settings.containsKey('address')) return outbound;

    final protocol = outbound['protocol'] as String? ?? '';
    final Map<String, dynamic> normalized;
    switch (protocol) {
      case 'vless':
        if (settings.containsKey('vnext')) return outbound;
        normalized = _vnextSettings(settings, {
          'id': settings['id'],
          'encryption': settings['encryption'] ?? 'none',
          'flow': settings['flow'] ?? '',
          'level': settings['level'] ?? 8,
        });
      case 'vmess':
        if (settings.containsKey('vnext')) return outbound;
        normalized = _vnextSettings(settings, {
          'id': settings['id'],
          'alterId': settings['alterId'] ?? 0,
          'security': settings['security'] ?? 'auto',
          'level': settings['level'] ?? 8,
        });
      case 'trojan':
        if (settings.containsKey('servers')) return outbound;
        normalized = {
          'servers': [
            {
              'address': settings['address'],
              'port': settings['port'],
              'password': settings['password'],
              'level': settings['level'] ?? 8,
            },
          ],
        };
      case 'shadowsocks':
        if (settings.containsKey('servers')) return outbound;
        normalized = {
          'servers': [
            {
              'address': settings['address'],
              'port': settings['port'],
              'method': settings['method'],
              'password': settings['password'],
              'level': settings['level'] ?? 8,
            },
          ],
        };
      default:
        return outbound;
    }
    return {...outbound, 'settings': normalized};
  }

  Map<String, dynamic> _vnextSettings(
    Map<String, dynamic> settings,
    Map<String, dynamic> fallbackUser,
  ) {
    final users = settings['users'];
    return {
      'vnext': [
        {
          'address': settings['address'],
          'port': settings['port'],
          'users': users is List && users.isNotEmpty ? users : [fallbackUser],
        },
      ],
    };
  }

  (String, int, String)? _extractAddressPort(Map<String, dynamic> settings) {
    if (settings.containsKey('vnext')) {
      final vnext = settings['vnext'] as List<dynamic>;
      if (vnext.isEmpty) return null;
      final node = vnext[0] as Map<String, dynamic>;
      final port = _parsePort(node['port']);
      if (port == null) return null;
      return (node['address'] as String, port, _extractUuid(node));
    }
    if (settings.containsKey('servers')) {
      final servers = settings['servers'] as List<dynamic>;
      if (servers.isEmpty) return null;
      final node = servers[0] as Map<String, dynamic>;
      final port = _parsePort(node['port']);
      if (port == null) return null;
      return (node['address'] as String, port, '');
    }
    if (settings.containsKey('address')) {
      final port = _parsePort(settings['port']);
      if (port == null) return null;
      return (settings['address'] as String, port, _extractUuid(settings));
    }
    return null;
  }

  // Reads the first user's id (uuid) from a vnext/settings node, if present.
  String _extractUuid(Map<String, dynamic> node) {
    final users = node['users'] as List<dynamic>?;
    if (users == null || users.isEmpty) return '';
    final user = users[0] as Map<String, dynamic>?;
    return user?['id'] as String? ?? '';
  }

  // Parses a port from either an int or a numeric string, validating its range.
  int? _parsePort(dynamic value) {
    final port = value is int
        ? value
        : (value is String ? int.tryParse(value) : null);
    if (port == null || port <= 0 || port > 65535) return null;
    return port;
  }

  Map<String, dynamic> _buildServerConfig(
    Map<String, dynamic> config,
    Map<String, dynamic> originalProxyOutbound,
    Map<String, dynamic> normalizedProxyOutbound,
  ) {
    final originalProxyTag = originalProxyOutbound['tag'] as String? ?? '';
    final proxyOutbound = {...normalizedProxyOutbound, 'tag': 'proxy'};

    final extraOutbounds = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>()
        .where((o) {
          if (identical(o, originalProxyOutbound)) return false;
          final tag = o['tag'] as String? ?? '';
          return tag != 'proxy' && !tag.startsWith('proxy-');
        });
    final outbounds = <Map<String, dynamic>>[proxyOutbound, ...extraOutbounds];

    final tags = outbounds.map((o) => o['tag'] as String? ?? '').toSet();
    if (!tags.contains('direct')) {
      outbounds.add(<String, dynamic>{
        'protocol': 'freedom',
        'settings': {'domainStrategy': 'UseIP'},
        'tag': 'direct',
      });
    }
    if (!tags.contains('block')) {
      outbounds.add(<String, dynamic>{
        'protocol': 'blackhole',
        'settings': {
          'response': {'type': 'http'},
        },
        'tag': 'block',
      });
    }
    final validTags = outbounds.map((o) => o['tag'] as String? ?? '').toSet();

    final result = {
      ...config,
      'outbounds': outbounds,
      'stats': <String, dynamic>{},
      'policy': {
        ...?config['policy'] as Map<String, dynamic>?,
        'system': {
          ...?(config['policy'] as Map<String, dynamic>?)?['system']
              as Map<String, dynamic>?,
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        },
      },
    };

    result.remove('observatory');
    result.remove('burstObservatory');

    final routing = _sanitizeRouting(
      config['routing'],
      validTags,
      originalProxyTag,
    );
    if (routing == null) {
      result.remove('routing');
    } else {
      result['routing'] = routing;
    }

    return result;
  }

  static const _geoPrefixByField = {'domain': 'geosite:', 'ip': 'geoip:'};
  static const _ruleMetaKeys = {'type', 'outboundTag', 'balancerTag'};

  Map<String, dynamic>? _sanitizeRouting(
    dynamic routing,
    Set<String> validTags,
    String originalProxyTag,
  ) {
    if (routing is! Map<String, dynamic>) return null;

    final result = Map<String, dynamic>.from(routing);
    result.remove('balancers');

    if (routing['rules'] is! List) return result;

    final rules = (routing['rules'] as List)
        .map((rule) {
          if (rule is! Map<String, dynamic>) return rule;
          final sanitized = Map<String, dynamic>.from(rule);
          if (originalProxyTag != 'proxy' &&
              sanitized['outboundTag'] == originalProxyTag) {
            sanitized['outboundTag'] = 'proxy';
          }
          _geoPrefixByField.forEach((field, prefix) {
            final values = sanitized[field];
            if (values is! List) return;
            final kept = values
                .where((v) => !(v is String && v.startsWith(prefix)))
                .toList();
            if (kept.isEmpty) {
              sanitized.remove(field);
            } else {
              sanitized[field] = kept;
            }
          });
          return sanitized;
        })
        .where((rule) {
          if (rule is! Map<String, dynamic>) return true;
          if (rule.containsKey('balancerTag')) {
            _talker.debug(
              'Parser: dropped a routing rule bound to a removed balancer',
            );
            return false;
          }
          final outboundTag = rule['outboundTag'];
          if (outboundTag is String && !validTags.contains(outboundTag)) {
            _talker.debug(
              'Parser: dropped a routing rule with non-existent outboundTag '
              '"$outboundTag"',
            );
            return false;
          }
          final hasMatcher = rule.keys.any((k) => !_ruleMetaKeys.contains(k));
          if (!hasMatcher) {
            _talker.debug(
              'Parser: dropped a routing rule left with nothing to match after '
              'stripping geosite/geoip',
            );
            return false;
          }
          return true;
        })
        .toList();

    result['rules'] = rules;
    return result;
  }
}
