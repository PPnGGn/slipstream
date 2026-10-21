import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/theme/app_palette.dart';

void main() {
  test('dark and light give each settings tile its own hue', () {
    expect(
      AppPalette.dark.tileHue(TileHue.routing),
      isNot(AppPalette.dark.tileHue(TileHue.dns)),
    );
    expect(
      AppPalette.light.tileHue(TileHue.routing),
      isNot(AppPalette.light.tileHue(TileHue.dns)),
    );
  });

  test('phosphor paints every tile in its accent', () {
    for (final hue in TileHue.values) {
      expect(AppPalette.phosphor.tileHue(hue), AppPalette.phosphor.accentIcon);
    }
  });

  test('phosphor accent is solid, not a gradient', () {
    final [first, last] = AppPalette.phosphor.brandGradient;
    expect(first, last);
  });
}
