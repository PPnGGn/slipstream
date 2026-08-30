import 'dart:convert';

class XrayServerMeta {
  const XrayServerMeta({
    this.protocol,
    this.network,
    this.security,
    this.host,
    this.port,
  });

  final String? protocol;
  final String? network;
  final String? security;
  final String? host;
  final int? port;

  bool get hasEndpoint => host != null && host!.isNotEmpty && port != null;

  String get protocolLabel => (protocol ?? 'proxy').toUpperCase();
  String? get networkLabel => network?.toUpperCase();
  String? get securityLabel => security?.toUpperCase();
}

XrayServerMeta readXrayServerMeta(String configJson) {
  try {
    final json = jsonDecode(configJson) as Map<String, dynamic>;
    final outbounds = (json['outbounds'] as List).cast<Map<String, dynamic>>();
    final proxy = outbounds.firstWhere((o) => (o['tag'] as String?) == 'proxy');

    final stream = proxy['streamSettings'] as Map<String, dynamic>?;
    final endpoint = _endpoint(proxy['settings'] as Map<String, dynamic>?);

    return XrayServerMeta(
      protocol: proxy['protocol'] as String?,
      network: stream?['network'] as String?,
      security: stream?['security'] as String?,
      host: endpoint?.$1,
      port: endpoint?.$2,
    );
  } catch (_) {
    return const XrayServerMeta();
  }
}

(String, int)? _endpoint(Map<String, dynamic>? settings) {
  if (settings == null) return null;

  final vnext = settings['vnext'];
  final servers = settings['servers'];
  final Map<String, dynamic>? node;
  if (vnext is List && vnext.isNotEmpty) {
    node = vnext.first as Map<String, dynamic>;
  } else if (servers is List && servers.isNotEmpty) {
    node = servers.first as Map<String, dynamic>;
  } else {
    node = null;
  }
  if (node == null) return null;

  final host = node['address'] as String?;
  final rawPort = node['port'];
  final port = rawPort is int ? rawPort : int.tryParse('$rawPort');
  if (host == null || host.isEmpty || port == null) return null;
  return (host, port);
}
