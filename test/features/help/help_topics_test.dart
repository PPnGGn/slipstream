import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/l10n/gen/app_localizations.dart';

import '../../helpers/l10n.dart';

/// All text of a topic in one string, for "does it mention X" checks.
String _allText(HelpTopic topic) => [
  topic.title,
  topic.intro,
  for (final item in topic.items) ...[
    item.title,
    item.what,
    item.why,
    ?item.tip,
  ],
  for (final note in topic.notes) ...[note.title, note.body],
].join('\n');

List<String> _titles(HelpTopic topic) =>
    topic.items.map((item) => item.title).toList();

void main() {
  final topics = <String, HelpTopic>{
    'ping': pingHelp(l10nEn),
    'subscriptions (background)': subscriptionsHelp(
      l10nEn,
      backgroundUpdates: true,
    ),
    'subscriptions (foreground)': subscriptionsHelp(
      l10nEn,
      backgroundUpdates: false,
    ),
    'dns': dnsHelp(l10nEn, fakeDnsAllowed: true),
    'dns (no fake dns)': dnsHelp(l10nEn, fakeDnsAllowed: false),
    'routing': routingHelp(l10nEn, fullAdBlockAllowed: true),
    'routing (limited ad block)': routingHelp(
      l10nEn,
      fullAdBlockAllowed: false,
    ),
    'security': securityHelp(l10nEn),
    'split tunneling': splitTunnelHelp(l10nEn),
  };

  for (final MapEntry(key: name, value: topic) in topics.entries) {
    group('$name help', () {
      test('has a title, an intro and at least one item', () {
        expect(topic.title.trim(), isNotEmpty);
        expect(topic.intro.trim(), isNotEmpty);
        expect(topic.items, isNotEmpty);
      });

      test('says what every item does and why it is needed', () {
        for (final item in topic.items) {
          expect(item.title.trim(), isNotEmpty);
          expect(item.what.trim(), isNotEmpty, reason: '${item.title}: what');
          expect(item.why.trim(), isNotEmpty, reason: '${item.title}: why');
          expect(item.iconPath, startsWith('assets/svg/'));
        }
      });

      test('has no two items with the same title', () {
        expect(_titles(topic).toSet().length, topic.items.length);
      });

      test('has complete notes', () {
        for (final note in topic.notes) {
          expect(note.title.trim(), isNotEmpty);
          expect(note.body.trim(), isNotEmpty);
        }
      });

      test('is written in English (only the .рф zone name is Cyrillic)', () {
        final text = _allText(topic).replaceAll('.рф', '');
        expect(RegExp('[А-Яа-яЁё]').hasMatch(text), isFalse);
      });
    });
  }

  group('item titles match the rows on the pages', () {
    test('ping', () {
      expect(_titles(pingHelp(l10nEn)), [
        'Ping on launch',
        'Sort servers by latency',
        'Latency display',
      ]);
    });

    test('subscriptions', () {
      expect(_titles(subscriptionsHelp(l10nEn, backgroundUpdates: true)), [
        'Auto-update',
      ]);
    });

    test('dns', () {
      expect(_titles(dnsHelp(l10nEn, fakeDnsAllowed: true)), [
        'Remote DNS',
        'Direct DNS',
        'Fake DNS',
      ]);
    });

    test('routing', () {
      expect(_titles(routingHelp(l10nEn, fullAdBlockAllowed: true)), [
        'RU bypass',
        'Ad & tracker blocking',
        'LAN bypass',
        'Geo databases',
        'Custom rules',
      ]);
    });

    test('security', () {
      expect(_titles(securityHelp(l10nEn)), ['Kill switch', 'IPv6']);
    });

    test('split tunneling', () {
      expect(_titles(splitTunnelHelp(l10nEn)), [
        'Split tunneling',
        'Proxy selected / Bypass selected',
        'Include system apps',
      ]);
    });
  });

  group('platform variants', () {
    test('routing: the full ad list is offered only where it fits', () {
      final full = _allText(routingHelp(l10nEn, fullAdBlockAllowed: true));
      final limited = _allText(routingHelp(l10nEn, fullAdBlockAllowed: false));

      expect(full, contains('Full'));
      expect(limited, isNot(contains('Full')));
      expect(limited, contains('iOS'));
    });

    test('dns: Fake DNS is described only where it exists', () {
      expect(
        _titles(dnsHelp(l10nEn, fakeDnsAllowed: true)),
        contains('Fake DNS'),
      );
      expect(
        _titles(dnsHelp(l10nEn, fakeDnsAllowed: false)),
        isNot(contains('Fake DNS')),
      );
      expect(
        _allText(dnsHelp(l10nEn, fakeDnsAllowed: false)),
        isNot(contains('Fake DNS')),
      );
    });

    test('subscriptions: the background schedule is told only on Android', () {
      final background = _allText(
        subscriptionsHelp(l10nEn, backgroundUpdates: true),
      );
      final foreground = _allText(
        subscriptionsHelp(l10nEn, backgroundUpdates: false),
      );

      expect(background, contains('background'));
      expect(foreground, isNot(contains('background')));
    });
  });

  group('every language', () {
    // The same topics in each language: complete, with the same shape as
    // English (a translation must not drop a card or a note).
    List<HelpTopic> all(AppLocalizations l10n) => [
      pingHelp(l10n),
      subscriptionsHelp(l10n, backgroundUpdates: true),
      subscriptionsHelp(l10n, backgroundUpdates: false),
      dnsHelp(l10n, fakeDnsAllowed: true),
      dnsHelp(l10n, fakeDnsAllowed: false),
      routingHelp(l10n, fullAdBlockAllowed: true),
      routingHelp(l10n, fullAdBlockAllowed: false),
      securityHelp(l10n),
      splitTunnelHelp(l10n),
    ];

    final english = all(l10nEn);

    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode} has the shape of English', () {
        final topics = all(lookupAppLocalizations(locale));
        for (final (i, topic) in topics.indexed) {
          final base = english[i];
          expect(topic.items.length, base.items.length, reason: base.title);
          expect(topic.notes.length, base.notes.length, reason: base.title);
          for (final item in topic.items) {
            expect(item.what.trim(), isNotEmpty);
            expect(item.why.trim(), isNotEmpty);
          }
          for (final (j, item) in topic.items.indexed) {
            expect(item.tip == null, base.items[j].tip == null);
          }
        }
      });
    }

    test(
      'Russian topics are Russian, with the zone names kept as they are',
      () {
        final topic = routingHelp(l10nRu, fullAdBlockAllowed: true);
        expect(topic.title, 'Маршрутизация');
        expect(topic.items.first.what, contains('.ru / .рф'));
      },
    );
  });

  group('shared notes', () {
    test('settings that need a reconnect say so', () {
      for (final topic in [
        dnsHelp(l10nEn, fakeDnsAllowed: true),
        routingHelp(l10nEn, fullAdBlockAllowed: true),
        securityHelp(l10nEn),
        splitTunnelHelp(l10nEn),
      ]) {
        expect(_allText(topic), contains('reconnect'), reason: topic.title);
      }
    });
  });
}
