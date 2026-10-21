import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/protocol_colors.dart';

void main() {
  test('a known label takes its color from the design table', () {
    expect(protocolColor('VLESS', AppPalette.dark), const Color(0xFF6F9BFF));
    expect(protocolColor('REALITY', AppPalette.dark), const Color(0xFFF2CC4B));
    expect(protocolColor('XHTTP', AppPalette.dark), const Color(0xFFF5A742));
  });

  test('the label is case-insensitive', () {
    expect(
      protocolColor('vless', AppPalette.dark),
      protocolColor('VLESS', AppPalette.dark),
    );
  });

  test('hysteria from the config shares the HYSTERIA2 color', () {
    expect(
      protocolColor('HYSTERIA', AppPalette.dark),
      protocolColor('HYSTERIA2', AppPalette.dark),
    );
  });

  test('an unknown label falls back to grey', () {
    expect(protocolColor('KCP', AppPalette.dark), const Color(0xFF9AA0AE));
  });

  test('light darkens every channel to 62% for contrast on paper', () {
    expect(protocolColor('VLESS', AppPalette.light), const Color(0xFF45609E));
    expect(protocolColor('KCP', AppPalette.light), const Color(0xFF5F636C));
  });

  test('phosphor uses the dark colors as is', () {
    expect(
      protocolColor('TROJAN', AppPalette.phosphor),
      protocolColor('TROJAN', AppPalette.dark),
    );
  });
}
