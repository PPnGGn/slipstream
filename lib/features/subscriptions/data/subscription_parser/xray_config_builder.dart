import 'dart:convert';

// Transport/security parameters shared by all URI parsers.
class StreamOptions {
  const StreamOptions({
    this.network = 'tcp',
    this.security = 'none',
    this.sni = '',
    this.fp = '',
    this.alpn = '',
    this.pbk = '',
    this.sid = '',
    this.spx = '',
    this.path = '',
    this.host = '',
    this.serviceName = '',
    this.authority = '',
    this.headerType = '',
    this.seed = '',
    this.mode = '',
  });

  final String network; // tcp | ws | grpc | httpupgrade | xhttp | kcp
  final String security; // none | tls | reality
  final String sni;
  final String fp;
  final String alpn;
  final String pbk;
  final String sid;
  final String spx;
  final String path;
  final String host;
  final String serviceName;
  final String authority;
  final String headerType;
  final String seed;
  final String mode;
}

class XrayConfigBuilder {
  // Builds a full Xray client config (VLESS) for a single server.
  String buildVless({
    required String uuid,
    required String address,
    required int port,
    required String title,
    String flow = '',
    String encryption = '',
    StreamOptions stream = const StreamOptions(),
  }) {
    // xtls-rprx-vision is only valid on raw tcp with tls/reality
    final allowsFlow =
        stream.network == 'tcp' &&
        (stream.security == 'tls' || stream.security == 'reality');
    final proxyOutbound = {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": address,
            "port": port,
            "users": [
              {
                "encryption": encryption.isNotEmpty ? encryption : "none",
                if (allowsFlow && flow.isNotEmpty) "flow": flow,
                "id": uuid,
                "level": 8,
              },
            ],
          },
        ],
      },
      "streamSettings": _streamSettings(stream),
      "tag": "proxy",
    };
    return jsonEncode(_wrap(proxyOutbound, title));
  }

  // Builds a full Xray client config (VMess) for a single server.
  String buildVmess({
    required String uuid,
    required int alterId,
    required String security,
    required String address,
    required int port,
    required String title,
    StreamOptions stream = const StreamOptions(),
  }) {
    final proxyOutbound = {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": address,
            "port": port,
            "users": [
              {
                "alterId": alterId,
                "id": uuid,
                "level": 8,
                "security": security.isNotEmpty ? security : "auto",
              },
            ],
          },
        ],
      },
      "streamSettings": _streamSettings(stream),
      "tag": "proxy",
    };
    return jsonEncode(_wrap(proxyOutbound, title));
  }

  // Builds a full Xray client config (Trojan) for a single server.
  String buildTrojan({
    required String password,
    required String address,
    required int port,
    required String title,
    StreamOptions stream = const StreamOptions(security: 'tls'),
  }) {
    final proxyOutbound = {
      "protocol": "trojan",
      "settings": {
        "servers": [
          {"address": address, "port": port, "password": password, "level": 8},
        ],
      },
      "streamSettings": _streamSettings(stream),
      "tag": "proxy",
    };
    return jsonEncode(_wrap(proxyOutbound, title));
  }

  // Builds a full Xray client config (Hysteria2) for a single server.
  String buildHysteria2({
    required String password,
    required String address,
    required int port,
    required String title,
    String sni = '',
    String pinSHA256 = '',
    String obfsPassword = '',
    String mport = '',
  }) {
    final proxyOutbound = {
      "protocol": "hysteria",
      "settings": {"version": 2, "address": address, "port": port},
      "streamSettings": {
        "network": "hysteria",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h3"],
          "serverName": sni.isNotEmpty ? sni : address,
          if (pinSHA256.isNotEmpty) "pinnedPeerCertSha256": pinSHA256,
        },
        "hysteriaSettings": {"version": 2, "auth": password},
        if (obfsPassword.isNotEmpty || mport.isNotEmpty)
          "finalmask": {
            if (obfsPassword.isNotEmpty)
              "udp": [
                {
                  "type": "salamander",
                  "settings": {"password": obfsPassword},
                },
              ],
            if (mport.isNotEmpty)
              "quicParams": {
                "udpHop": {"ports": mport},
              },
          },
      },
      "tag": "proxy",
    };
    return jsonEncode(_wrap(proxyOutbound, title));
  }

  // Builds a full Xray client config (Shadowsocks) for a single server.
  String buildShadowsocks({
    required String method,
    required String password,
    required String address,
    required int port,
    required String title,
    StreamOptions stream = const StreamOptions(),
  }) {
    final proxyOutbound = {
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": address,
            "port": port,
            "method": method,
            "password": password,
            "level": 8,
          },
        ],
      },
      "streamSettings": _streamSettings(stream),
      "tag": "proxy",
    };
    return jsonEncode(_wrap(proxyOutbound, title));
  }

  // allowInsecure is never emitted: xray-core removed it (hard error since
  // 2026-06-01), pinnedPeerCertSha256 is the replacement.
  Map<String, dynamic> _streamSettings(StreamOptions o) {
    final stream = <String, dynamic>{
      "network": o.network,
      "security": o.security,
    };
    final alpn = _csv(o.alpn);

    switch (o.security) {
      case 'tls':
        stream["tlsSettings"] = {
          if (alpn.isNotEmpty) "alpn": alpn,
          "fingerprint": o.fp.isNotEmpty ? o.fp : "chrome",
          "serverName": o.sni,
          "show": false,
        };
      case 'reality':
        stream["realitySettings"] = {
          "allowInsecure": false,
          "fingerprint": o.fp.isNotEmpty ? o.fp : "chrome",
          "publicKey": o.pbk,
          "serverName": o.sni,
          "shortId": o.sid,
          if (o.spx.isNotEmpty) "spiderX": o.spx,
          "show": false,
        };
    }

    switch (o.network) {
      case 'ws':
        stream["wsSettings"] = {
          if (o.host.isNotEmpty) "headers": {"Host": o.host},
          "path": o.path.isNotEmpty ? o.path : "/",
        };
      case 'grpc':
        stream["grpcSettings"] = {
          if (o.authority.isNotEmpty) "authority": o.authority,
          "multiMode": o.mode.trim().toLowerCase() == 'multi',
          "serviceName": o.serviceName,
        };
      case 'httpupgrade':
        stream["httpupgradeSettings"] = {
          if (o.host.isNotEmpty) "host": o.host,
          "path": o.path.isNotEmpty ? o.path : "/",
        };
      case 'xhttp':
        stream["xhttpSettings"] = {
          if (o.host.isNotEmpty) "host": o.host,
          if (o.mode.isNotEmpty) "mode": o.mode,
          "path": o.path.isNotEmpty ? o.path : "/",
        };
      case 'kcp':
        stream["kcpSettings"] = {
          "header": {"type": o.headerType.isNotEmpty ? o.headerType : "none"},
          if (o.seed.isNotEmpty) "seed": o.seed,
        };
      default:
        stream["tcpSettings"] = {"header": _tcpHeader(o)};
    }

    return stream;
  }

  List<String> _csv(String raw) =>
      raw.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();

  // headerType=http is the fake http obfuscation, it needs a whole request
  // template and not just the type
  Map<String, dynamic> _tcpHeader(StreamOptions o) {
    final type = o.headerType.isNotEmpty ? o.headerType : "none";
    if (type != "http") return {"type": type};
    return {
      "type": "http",
      "request": {
        "version": "1.1",
        "method": "GET",
        "path": [o.path.isNotEmpty ? o.path : "/"],
        "headers": {
          if (o.host.isNotEmpty) "Host": _csv(o.host),
          "Accept-Encoding": const ["gzip, deflate"],
          "Connection": const ["keep-alive"],
          "Pragma": "no-cache",
        },
      },
    };
  }

  // Wraps a proxy outbound into a complete client config (shared inbounds/dns/routing).
  Map<String, dynamic> _wrap(Map<String, dynamic> proxyOutbound, String title) {
    return {
      "dns": {
        "queryStrategy": "UseIP",
        "servers": ["https://8.8.8.8/dns-query", "https://8.8.4.4/dns-query"],
      },
      // fixed local ports, the app always points its socks/http proxy here
      "inbounds": [
        {
          "listen": "127.0.0.1",
          "port": 10808,
          "protocol": "socks",
          "settings": {"auth": "noauth", "udp": true, "userLevel": 8},
          "sniffing": {
            "destOverride": ["http", "tls"],
            "enabled": true,
            "routeOnly": false,
          },
          "tag": "socks",
        },
        {
          "listen": "127.0.0.1",
          "port": 10809,
          "protocol": "http",
          "settings": {"userLevel": 8},
          "tag": "http",
        },
      ],
      "log": {"loglevel": "info"},
      "outbounds": [
        proxyOutbound,
        {
          "protocol": "freedom",
          "settings": {"domainStrategy": "UseIP"},
          "tag": "direct",
        },
        {
          "protocol": "blackhole",
          "settings": {
            "response": {"type": "http"},
          },
          "tag": "block",
        },
      ],
      "stats": <String, dynamic>{},
      "policy": {
        "system": {"statsOutboundUplink": true, "statsOutboundDownlink": true},
      },
      "remarks": title,
      "routing": {
        "domainMatcher": "hybrid",
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {
            "outboundTag": "direct",
            "protocol": ["bittorrent"],
            "type": "field",
          },
        ],
      },
    };
  }
}
