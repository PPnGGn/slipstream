import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/routing/data/custom_rule_value.dart';

void main() {
  void expectValue(String input, String expected) {
    final result = parseRuleValue(input);
    expect(result.error, isNull, reason: 'input: "$input"');
    expect(result.value, expected, reason: 'input: "$input"');
  }

  void expectError(String input, RuleInputError error) {
    final result = parseRuleValue(input);
    expect(result.value, isNull, reason: 'input: "$input"');
    expect(result.error, error, reason: 'input: "$input"');
  }

  group('domains are brought to one form', () {
    test('plain domain, trimmed and lower-cased', () {
      expectValue('example.com', 'example.com');
      expectValue('  YouTube.COM  ', 'youtube.com');
    });

    test('wildcard prefix and dots at the ends are dropped', () {
      expectValue('*.youtube.com', 'youtube.com');
      expectValue('.youtube.com', 'youtube.com');
      expectValue('youtube.com.', 'youtube.com');
    });

    test('a pasted link is cut down to its host', () {
      expectValue('https://www.site.com/path?x=1#top', 'www.site.com');
      expectValue('http://site.com:8080/a', 'site.com');
      expectValue('site.com/path', 'site.com');
    });

    test('a port is dropped', () {
      expectValue('site.com:443', 'site.com');
    });

    test('single labels, punycode and underscores are fine', () {
      expectValue('localhost', 'localhost');
      expectValue('router', 'router');
      expectValue('xn--p1ai', 'xn--p1ai');
      expectValue('xn--80aswg.xn--p1ai', 'xn--80aswg.xn--p1ai');
      expectValue('my_host.example.com', 'my_host.example.com');
    });
  });

  group('IP addresses and ranges', () {
    test('IPv4 and IPv6 stay as typed (lower-cased)', () {
      expectValue('1.2.3.4', '1.2.3.4');
      expectValue('::1', '::1');
      expectValue('2001:DB8::1', '2001:db8::1');
    });

    test('CIDR ranges', () {
      expectValue('10.0.0.0/8', '10.0.0.0/8');
      expectValue('192.168.1.0/24', '192.168.1.0/24');
      expectValue('2001:db8::/32', '2001:db8::/32');
    });

    test('a single-host prefix collapses to the plain address', () {
      expectValue('1.2.3.4/32', '1.2.3.4');
      expectValue('::1/128', '::1');
    });

    test('link and port around an address are dropped', () {
      expectValue('http://1.2.3.4/path', '1.2.3.4');
      expectValue('1.2.3.4:8080', '1.2.3.4');
      expectValue('https://[2001:db8::1]/x', '2001:db8::1');
      expectValue('[2001:db8::1]:443', '2001:db8::1');
    });
  });

  group('errors', () {
    test('nothing typed', () {
      expectError('', RuleInputError.empty);
      expectError('   ', RuleInputError.empty);
    });

    test('non-ASCII names ask for punycode', () {
      expectError('привет.рф', RuleInputError.nonAscii);
      expectError('пример.com', RuleInputError.nonAscii);
    });

    test('prefix out of range or not a number', () {
      expectError('10.0.0.0/33', RuleInputError.badPrefix);
      expectError('::/129', RuleInputError.badPrefix);
      expectError('10.0.0.0/abc', RuleInputError.badPrefix);
      expectError('10.0.0.0/-1', RuleInputError.badPrefix);
      expectError('10.0.0.0/', RuleInputError.badPrefix);
    });

    test('things that are neither a domain nor an address', () {
      expectError('exa mple.com', RuleInputError.invalid);
      expectError('a..b.com', RuleInputError.invalid);
      expectError('-a.com', RuleInputError.invalid);
      expectError('a-.com', RuleInputError.invalid);
      expectError('foo@bar.com', RuleInputError.invalid);
      expectError('a.b*', RuleInputError.invalid);
      expectError('*', RuleInputError.invalid);
      expectError('http://', RuleInputError.invalid);
    });

    test('geo tokens and other xray prefixes are not accepted', () {
      expectError('geosite:ru', RuleInputError.invalid);
      expectError('geoip:ru', RuleInputError.invalid);
      expectError('domain:example.com', RuleInputError.invalid);
      expectError('regexp:.*', RuleInputError.invalid);
    });

    test('a broken address is not taken for a domain', () {
      expectError('300.1.1.1', RuleInputError.invalid);
      expectError('1.2.3', RuleInputError.invalid);
      expectError('fe80::1%eth0', RuleInputError.invalid);
    });

    test('a label over 63 characters, a name over 253', () {
      expectError('${'a' * 64}.com', RuleInputError.invalid);
      expectValue('${'a' * 63}.com', '${'a' * 63}.com');
      expectError(List.filled(60, 'abcd').join('.'), RuleInputError.invalid);
    });
  });

  group('parseIpValue', () {
    test('plain address has the full prefix', () {
      expect(parseIpValue('1.2.3.4')?.prefix, 32);
      expect(parseIpValue('::1')?.prefix, 128);
    });

    test('CIDR keeps its prefix', () {
      expect(parseIpValue('10.0.0.0/8')?.prefix, 8);
      expect(parseIpValue('2001:db8::/32')?.prefix, 32);
    });

    test('a domain is not an IP', () {
      expect(parseIpValue('example.com'), isNull);
    });
  });
}
