import 'dart:ui';

import 'package:slipstream/core/theme/app_palette.dart';

// Design `PROTO_C`: protocol, transport and security tags on server rows.
const _protocolColors = {
  'VLESS': Color(0xFF6F9BFF),
  'VMESS': Color(0xFF3FC7B4),
  'TROJAN': Color(0xFFFF8A65),
  'SHADOWSOCKS': Color(0xFF6BD66B),
  'HYSTERIA2': Color(0xFFE26FD0),
  // The config's protocol is "hysteria"; the UI calls it HYSTERIA2.
  'HYSTERIA': Color(0xFFE26FD0),
  'WIREGUARD': Color(0xFFA07CFF),
  'TUIC': Color(0xFFFFB454),
  'TCP': Color(0xFF9AA0AE),
  'XHTTP': Color(0xFFF5A742),
  'WS': Color(0xFF4FC3F7),
  'GRPC': Color(0xFFD4A5FF),
  'QUIC': Color(0xFFFF7EA8),
  'UDP': Color(0xFFB5C49A),
  'REALITY': Color(0xFFF2CC4B),
  'TLS': Color(0xFF5FE0A8),
};

const _unknownColor = Color(0xFF9AA0AE);

/// Color of one tag (`VLESS`, `XHTTP`, `REALITY`…). The table is tuned for
/// dark backgrounds, so on a light palette every channel is scaled to 62%.
Color protocolColor(String label, AppPalette palette) {
  final color = _protocolColors[label.toUpperCase()] ?? _unknownColor;
  if (palette.brightness == Brightness.dark) return color;

  // Same math as the design's JS: an 8-bit channel times .62, rounded.
  int darken(double channel) => ((channel * 255).round() * .62).round();
  return Color.fromARGB(255, darken(color.r), darken(color.g), darken(color.b));
}
