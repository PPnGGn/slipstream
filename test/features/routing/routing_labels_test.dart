import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/ui/routing_labels.dart';

import '../../helpers/l10n.dart';

final _ready = GeoState.ready(
  catalog: const GeoCatalog.empty(),
  tag: 'v1.2',
  updatedAt: DateTime(2026, 11, 8),
);

final _updateAvailable = GeoState.updateAvailable(
  catalog: const GeoCatalog.empty(),
  tag: 'v1.2',
  updatedAt: DateTime(2026, 11, 8),
  latestTag: 'v1.3',
);

void main() {
  group('geoStatusText', () {
    test('absent', () {
      expect(geoStatusText(l10nEn, const GeoState.absent()), 'Not downloaded');
    });

    test('checking', () {
      expect(
        geoStatusText(l10nEn, const GeoState.checking()),
        'Checking for updates…',
      );
    });

    test('downloading shows the percent', () {
      expect(
        geoStatusText(
          l10nEn,
          const GeoState.downloading(fraction: 0.426, received: 1, total: 2),
        ),
        'Downloading… 43%',
      );
    });

    test('ready shows the tag and the date', () {
      expect(geoStatusText(l10nEn, _ready), 'Up to date · v1.2 · 08.11.2026');
    });

    test('update available names the new tag', () {
      expect(geoStatusText(l10nEn, _updateAvailable), 'Update available: v1.3');
    });

    test('failed shows the message as it is', () {
      expect(
        geoStatusText(l10nEn, const GeoState.failed('No network')),
        'No network',
      );
    });
  });

  group('geoActionLabel', () {
    test('has a button where the user can act', () {
      expect(geoActionLabel(l10nEn, const GeoState.absent()), 'Download');
      expect(geoActionLabel(l10nEn, _ready), 'Update');
      expect(geoActionLabel(l10nEn, _updateAvailable), 'Update');
      expect(geoActionLabel(l10nEn, const GeoState.failed('x')), 'Retry');
    });

    test('has none while busy', () {
      expect(geoActionLabel(l10nEn, const GeoState.checking()), isNull);
      expect(
        geoActionLabel(
          l10nEn,
          const GeoState.downloading(fraction: 0, received: 0, total: 1),
        ),
        isNull,
      );
    });
  });

  group('routingSummary', () {
    String summary({
      RuBypassMode ru = RuBypassMode.bypassRu,
      AdBlockMode ads = AdBlockMode.off,
      int rules = 0,
      GeoState geo = const GeoState.absent(),
    }) => routingSummary(
      l10nEn,
      ruBypass: ru,
      adBlock: ads,
      customRules: rules,
      geo: geo,
    );

    test('joins the parts with a dot', () {
      expect(
        summary(ads: AdBlockMode.basic, geo: _ready),
        'RU bypass · ads: basic · geo databases up to date',
      );
    });

    test('says what is off', () {
      expect(
        summary(ru: RuBypassMode.off),
        'RU bypass off · ads off · geo databases not downloaded',
      );
    });

    test('names the full ad list', () {
      expect(summary(ads: AdBlockMode.full), contains('ads: full'));
    });

    test('counts custom rules only when there are some', () {
      expect(summary(), isNot(contains('rule')));
      expect(summary(rules: 1), contains('1 rule'));
      expect(summary(rules: 3), contains('3 rules'));
    });

    test('tells the state of the geo databases', () {
      expect(
        summary(geo: const GeoState.checking()),
        endsWith('checking geo databases…'),
      );
      expect(
        summary(
          geo: const GeoState.downloading(fraction: 0.5, received: 1, total: 2),
        ),
        endsWith('geo databases: 50%'),
      );
      expect(summary(geo: _updateAvailable), endsWith('geo update available'));
      expect(
        summary(geo: const GeoState.failed('x')),
        endsWith('geo download failed'),
      );
    });

    test('is written in English', () {
      final text = summary(ads: AdBlockMode.full, rules: 2, geo: _ready);
      expect(RegExp('[А-Яа-яЁё]').hasMatch(text), isFalse);
    });
  });
}
