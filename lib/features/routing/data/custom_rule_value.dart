import 'dart:io';

/// Why a typed rule value was refused.
enum RuleInputError {
  /// Nothing typed.
  empty,

  /// Neither a domain nor an IP address / range.
  invalid,

  /// A name with non-ASCII letters. xray matches the ASCII (punycode) form,
  /// so `привет.рф` has to be typed as `xn--b1agh1afp.xn--p1ai`.
  nonAscii,

  /// A range whose prefix is not a number or is out of range for the family.
  badPrefix,

  /// Another rule already has this value. Set by the cubit, which knows the
  /// other rules; [parseRuleValue] never returns it.
  duplicate,
}

/// What [parseRuleValue] made of the input: the normal form of the value, or
/// the reason it was refused. Exactly one of the two is set.
typedef RuleValueResult = ({String? value, RuleInputError? error});

final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://');
final _pathStart = RegExp(r'[/?#]');
final _digits = RegExp(r'^\d+$');
final _label = RegExp(r'^[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?$');
final _zone = RegExp(r'^([a-z]{2,63}|xn--[a-z0-9-]*[a-z0-9])$');

/// Brings what the user typed to one form, so that the same site written two
/// ways is one rule: a domain (`example.com`, written without scheme, path,
/// port, `*.` or dots at the ends), an IP address, or a range (`10.0.0.0/8`).
/// A pasted link is cut down to its host. `geosite:` and other xray prefixes
/// are not accepted: the geo data on the phone is trimmed to Russian services
/// and ads, so such a rule would match nothing.
RuleValueResult parseRuleValue(String input) {
  var text = input.trim().toLowerCase();
  if (text.isEmpty) return _fail(RuleInputError.empty);
  if (text.codeUnits.any((c) => c > 127)) {
    return _fail(RuleInputError.nonAscii);
  }

  final hadScheme = _scheme.hasMatch(text);
  if (hadScheme) text = text.replaceFirst(_scheme, '');

  // `ip/prefix` is a range. Not with a scheme: there `/…` is a path.
  if (!hadScheme) {
    final slash = text.indexOf('/');
    if (slash >= 0) {
      var address = text.substring(0, slash);
      if (address.startsWith('[') && address.endsWith(']')) {
        address = address.substring(1, address.length - 1);
      }
      final ip = InternetAddress.tryParse(address);
      if (ip != null && !address.contains('%')) {
        return _range(address, ip, text.substring(slash + 1));
      }
    }
  }

  final pathAt = text.indexOf(_pathStart);
  if (pathAt >= 0) text = text.substring(0, pathAt);

  final host = _hostOf(text);
  if (host == null) return _fail(RuleInputError.invalid);

  if (host.contains('%')) return _fail(RuleInputError.invalid);
  if (InternetAddress.tryParse(host) != null) return (value: host, error: null);

  final domain = _domain(host);
  if (domain == null) return _fail(RuleInputError.invalid);
  return (value: domain, error: null);
}

/// An IP value split into its address and prefix length (a plain address has
/// the full length of its family), or null when [value] is not an IP value.
({InternetAddress address, int prefix})? parseIpValue(String value) {
  final slash = value.indexOf('/');
  final address = InternetAddress.tryParse(
    slash < 0 ? value : value.substring(0, slash),
  );
  if (address == null) return null;
  final full = _fullPrefix(address);
  if (slash < 0) return (address: address, prefix: full);
  final prefix = int.tryParse(value.substring(slash + 1));
  if (prefix == null) return null;
  return (address: address, prefix: prefix);
}

int _fullPrefix(InternetAddress address) =>
    address.type == InternetAddressType.IPv6 ? 128 : 32;

RuleValueResult _fail(RuleInputError error) => (value: null, error: error);

RuleValueResult _range(String address, InternetAddress ip, String prefixText) {
  if (!_digits.hasMatch(prefixText)) return _fail(RuleInputError.badPrefix);
  final prefix = int.parse(prefixText);
  final full = _fullPrefix(ip);
  if (prefix > full) return _fail(RuleInputError.badPrefix);
  // One host: the plain address, so `1.2.3.4` and `1.2.3.4/32` are one rule.
  if (prefix == full) return (value: address, error: null);
  return (value: '$address/$prefix', error: null);
}

/// The host out of `host`, `host:port`, `[v6]` or `[v6]:port`; a bare IPv6
/// address (several colons) is a host as it is. Null if the port is not a
/// number or the brackets do not close.
String? _hostOf(String text) {
  if (text.startsWith('[')) {
    final close = text.indexOf(']');
    if (close < 0) return null;
    final rest = text.substring(close + 1);
    if (rest.isNotEmpty &&
        !(rest.startsWith(':') && _digits.hasMatch(rest.substring(1)))) {
      return null;
    }
    return text.substring(1, close);
  }
  final colons = ':'.allMatches(text).length;
  if (colons == 0 || colons > 1) return text;
  final colon = text.indexOf(':');
  final port = text.substring(colon + 1);
  if (!_digits.hasMatch(port)) return null;
  return text.substring(0, colon);
}

/// `*.example.com`, `.example.com` and `example.com.` are all `example.com`;
/// null when what is left is not a valid DNS name.
String? _domain(String host) {
  var name = host;
  if (name.startsWith('*.')) name = name.substring(2);
  while (name.startsWith('.')) {
    name = name.substring(1);
  }
  while (name.endsWith('.')) {
    name = name.substring(0, name.length - 1);
  }
  if (name.isEmpty || name.length > 253) return null;

  final labels = name.split('.');
  if (labels.any((l) => l.length > 63 || !_label.hasMatch(l))) return null;
  if (name == 'localhost') return name;
  // A real site has a dot and ends in a zone: letters (`com`, `ru`) or the
  // punycode form (`xn--p1ai`). That turns away a typed-in word (`hhshs`,
  // `router`) and a mistyped IP address (`300.1.1.1`, `1.2.3`) alike. A zone
  // list is not checked: it changes too often to ship in the app.
  if (labels.length < 2 || !_zone.hasMatch(labels.last)) return null;
  return name;
}
