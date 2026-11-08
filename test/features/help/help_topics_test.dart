import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';

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
    'ping': pingHelp(),
    'subscriptions (background)': subscriptionsHelp(backgroundUpdates: true),
    'subscriptions (foreground)': subscriptionsHelp(backgroundUpdates: false),
    'dns': dnsHelp(fakeDnsAllowed: true),
    'dns (no fake dns)': dnsHelp(fakeDnsAllowed: false),
    'routing': routingHelp(fullAdBlockAllowed: true),
    'routing (limited ad block)': routingHelp(fullAdBlockAllowed: false),
    'security': securityHelp(),
    'split tunneling': splitTunnelHelp(),
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
      expect(_titles(pingHelp()), [
        'Ping on launch',
        'Sort servers by latency',
        'Latency display',
      ]);
    });

    test('subscriptions', () {
      expect(_titles(subscriptionsHelp(backgroundUpdates: true)), [
        'Auto-update',
      ]);
    });

    test('dns', () {
      expect(_titles(dnsHelp(fakeDnsAllowed: true)), [
        'Remote DNS',
        'Direct DNS',
        'Fake DNS',
      ]);
    });

    test('routing', () {
      expect(_titles(routingHelp(fullAdBlockAllowed: true)), [
        'RU bypass',
        'Ad & tracker blocking',
        'LAN bypass',
        'Geo databases',
        'Custom rules',
      ]);
    });

    test('security', () {
      expect(_titles(securityHelp()), ['Kill switch', 'IPv6']);
    });

    test('split tunneling', () {
      expect(_titles(splitTunnelHelp()), [
        'Split tunneling',
        'Proxy selected / Bypass selected',
        'Include system apps',
      ]);
    });
  });

  group('platform variants', () {
    test('routing: the full ad list is offered only where it fits', () {
      final full = _allText(routingHelp(fullAdBlockAllowed: true));
      final limited = _allText(routingHelp(fullAdBlockAllowed: false));

      expect(full, contains('Full'));
      expect(limited, isNot(contains('Full')));
      expect(limited, contains('iOS'));
    });

    test('dns: Fake DNS is described only where it exists', () {
      expect(_titles(dnsHelp(fakeDnsAllowed: true)), contains('Fake DNS'));
      expect(
        _titles(dnsHelp(fakeDnsAllowed: false)),
        isNot(contains('Fake DNS')),
      );
      expect(
        _allText(dnsHelp(fakeDnsAllowed: false)),
        isNot(contains('Fake DNS')),
      );
    });

    test('subscriptions: the background schedule is told only on Android', () {
      final background = _allText(subscriptionsHelp(backgroundUpdates: true));
      final foreground = _allText(subscriptionsHelp(backgroundUpdates: false));

      expect(background, contains('background'));
      expect(foreground, isNot(contains('background')));
    });
  });

  group('shared notes', () {
    test('settings that need a reconnect say so', () {
      for (final topic in [
        dnsHelp(fakeDnsAllowed: true),
        routingHelp(fullAdBlockAllowed: true),
        securityHelp(),
        splitTunnelHelp(),
      ]) {
        expect(_allText(topic), contains('reconnect'), reason: topic.title);
      }
    });
  });
}
