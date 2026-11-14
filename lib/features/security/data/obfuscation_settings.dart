/// Settings of the two DPI-evasion options of Security & tunnel, both off by
/// default. They reach xray as finalmask masks on the server's own outbound
/// (see `applyObfuscation`), so they cost nothing while off.
///
/// - **Fragment** cuts the first TCP packets of a connection into small pieces
///   with a short pause between them, so a filter that looks for the TLS hello
///   in one piece does not find it. Works for servers that run over TCP.
/// - **Noise** sends a few random datagrams before the first real one, so a
///   filter does not recognise the handshake of a UDP protocol by its first
///   packet. Works for servers that run over UDP (Hysteria2, mKCP).
class ObfuscationSettings {
  const ObfuscationSettings({
    this.fragmentEnabled = false,
    this.fragment = const FragmentParams(),
    this.noiseEnabled = false,
    this.noise = const NoiseParams(),
  });

  final bool fragmentEnabled;
  final FragmentParams fragment;
  final bool noiseEnabled;
  final NoiseParams noise;

  ObfuscationSettings copyWith({
    bool? fragmentEnabled,
    FragmentParams? fragment,
    bool? noiseEnabled,
    NoiseParams? noise,
  }) => ObfuscationSettings(
    fragmentEnabled: fragmentEnabled ?? this.fragmentEnabled,
    fragment: fragment ?? this.fragment,
    noiseEnabled: noiseEnabled ?? this.noiseEnabled,
    noise: noise ?? this.noise,
  );

  @override
  bool operator ==(Object other) =>
      other is ObfuscationSettings &&
      other.fragmentEnabled == fragmentEnabled &&
      other.fragment == fragment &&
      other.noiseEnabled == noiseEnabled &&
      other.noise == noise;

  @override
  int get hashCode =>
      Object.hash(fragmentEnabled, fragment, noiseEnabled, noise);
}

/// How Fragment cuts. Every field is text the user can edit; [validateFragment]
/// says whether xray will take it and [normalized] writes it in the one form
/// xray reads.
class FragmentParams {
  const FragmentParams({
    this.packets = 'tlshello',
    this.length = '100-200',
    this.delay = '10-20',
  });

  /// Which packets of the connection are cut: `tlshello` (only the TLS hello,
  /// the first packet), or a range of packet numbers such as `1-3`.
  final String packets;

  /// Size of one piece in bytes, a range: xray draws each piece from it.
  final String length;

  /// Pause after each piece in milliseconds, a range.
  final String delay;

  FragmentParams copyWith({String? packets, String? length, String? delay}) =>
      FragmentParams(
        packets: packets ?? this.packets,
        length: length ?? this.length,
        delay: delay ?? this.delay,
      );

  /// Spaces gone, `150` written as `150-150`, `TLSHello` as `tlshello`.
  FragmentParams normalized() => FragmentParams(
    packets: _isTlsHello(packets) ? tlsHello : normalizeRange(packets),
    length: normalizeRange(length),
    delay: normalizeRange(delay),
  );

  @override
  bool operator ==(Object other) =>
      other is FragmentParams &&
      other.packets == packets &&
      other.length == length &&
      other.delay == delay;

  @override
  int get hashCode => Object.hash(packets, length, delay);
}

/// How Noise sends. Text for the same reason as [FragmentParams].
class NoiseParams {
  const NoiseParams({this.size = '10-20', this.delay = '10-16'});

  /// Size of one noise datagram in bytes, a range: xray draws it from there.
  final String size;

  /// Pause after the noise before the real datagram, in milliseconds.
  final String delay;

  NoiseParams copyWith({String? size, String? delay}) =>
      NoiseParams(size: size ?? this.size, delay: delay ?? this.delay);

  NoiseParams normalized() =>
      NoiseParams(size: normalizeRange(size), delay: normalizeRange(delay));

  @override
  bool operator ==(Object other) =>
      other is NoiseParams && other.size == size && other.delay == delay;

  @override
  int get hashCode => Object.hash(size, delay);
}

/// The value of `packets` that cuts only the TLS hello.
const tlsHello = 'tlshello';

bool _isTlsHello(String packets) => packets.trim().toLowerCase() == tlsHello;

/// Why a field is refused. The UI turns each into a sentence.
enum RangeInputError { empty, malformed, reversed, tooSmall, tooLarge }

typedef IntRange = ({int from, int to});

final _rangePattern = RegExp(r'^\s*(\d+)\s*(?:-\s*(\d+))?\s*$');

/// Reads `100-200`, or `150` as the range of one value. Null for anything else.
IntRange? parseRange(String raw) {
  final match = _rangePattern.firstMatch(raw);
  if (match == null) return null;
  final from = int.tryParse(match.group(1)!);
  final secondGroup = match.group(2);
  final to = secondGroup == null ? from : int.tryParse(secondGroup);
  if (from == null || to == null) return null;
  return (from: from, to: to);
}

/// Writes a range as `from-to`; text that is not a range is only trimmed.
String normalizeRange(String raw) {
  final range = parseRange(raw);
  return range == null ? raw.trim() : '${range.from}-${range.to}';
}

/// Null when [raw] is a range inside [min]..[max].
RangeInputError? validateRange(
  String raw, {
  required int min,
  required int max,
}) {
  if (raw.trim().isEmpty) return RangeInputError.empty;
  final range = parseRange(raw);
  if (range == null) return RangeInputError.malformed;
  if (range.from > range.to) return RangeInputError.reversed;
  if (range.from < min) return RangeInputError.tooSmall;
  if (range.to > max) return RangeInputError.tooLarge;
  return null;
}

// The bounds are about what xray accepts and what still makes sense: a piece
// of 0 bytes xray refuses; one over a network packet is not a piece; a pause
// of seconds per piece would stall the handshake until the app gives up.

typedef RangeBounds = ({int min, int max});

/// Packet numbers: the first packet up to the thousandth.
const fragmentPacketsBounds = (min: 1, max: 1000);

/// Bytes of one piece.
const fragmentLengthBounds = (min: 1, max: 1500);

/// Milliseconds after a piece, or after the noise.
const delayBounds = (min: 0, max: 500);

/// Bytes of one noise datagram: what fits a UDP packet on a 1500 byte link.
const noiseSizeBounds = (min: 1, max: 1400);

RangeInputError? _validate(String raw, RangeBounds bounds) =>
    validateRange(raw, min: bounds.min, max: bounds.max);

RangeInputError? validateFragmentPackets(String raw) =>
    _isTlsHello(raw) ? null : _validate(raw, fragmentPacketsBounds);

RangeInputError? validateFragmentLength(String raw) =>
    _validate(raw, fragmentLengthBounds);

RangeInputError? validateDelay(String raw) => _validate(raw, delayBounds);

RangeInputError? validateNoiseSize(String raw) =>
    _validate(raw, noiseSizeBounds);

class FragmentErrors {
  const FragmentErrors({this.packets, this.length, this.delay});

  final RangeInputError? packets;
  final RangeInputError? length;
  final RangeInputError? delay;

  bool get isValid => packets == null && length == null && delay == null;
}

class NoiseErrors {
  const NoiseErrors({this.size, this.delay});

  final RangeInputError? size;
  final RangeInputError? delay;

  bool get isValid => size == null && delay == null;
}

FragmentErrors validateFragment(FragmentParams params) => FragmentErrors(
  packets: validateFragmentPackets(params.packets),
  length: validateFragmentLength(params.length),
  delay: validateDelay(params.delay),
);

NoiseErrors validateNoise(NoiseParams params) => NoiseErrors(
  size: validateNoiseSize(params.size),
  delay: validateDelay(params.delay),
);
