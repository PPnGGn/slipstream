import 'dart:convert';

/// Re-indents a JSON string with two spaces; returns it unchanged if it doesn't
/// parse as JSON.
String prettyJson(String source) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(source));
  } catch (_) {
    return source;
  }
}

/// Human-readable byte count, e.g. 1536 -> "1.5 KB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fractionDigits = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unit]}';
}

/// Elapsed time as HH:MM:SS.
String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// Date only, e.g. "17.09.2026".
String formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

/// Update timestamp for display, e.g. "21.07.2026 14:03".
String formatUpdatedAt(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

const unknownCountryCode = 'XX';

/// Offset between an ASCII letter and its regional indicator symbol.
const _flagOffset = 0x1F1A5;
const _firstRegionalIndicator = 0x1F1E6;
const _lastRegionalIndicator = 0x1F1FF;

bool _isRegionalIndicator(int rune) =>
    rune >= _firstRegionalIndicator && rune <= _lastRegionalIndicator;

/// Turns a 2-letter country code into its flag emoji, e.g. "NL" -> "🇳🇱".
String countryFlag(String code) {
  if (code.length != 2) return '🏳️';
  final upper = code.toUpperCase();
  final first = upper.codeUnitAt(0) + _flagOffset;
  final second = upper.codeUnitAt(1) + _flagOffset;
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// True if [text] already opens with a flag emoji (a pair of regional
/// indicator symbols), so callers don't double up with their own flag.
bool startsWithFlagEmoji(String text) {
  final runes = text.runes.toList();
  if (runes.length < 2) return false;
  return _isRegionalIndicator(runes[0]) && _isRegionalIndicator(runes[1]);
}

/// Reverse of [countryFlag]: reads the 2-letter code out of a leading flag
/// emoji, e.g. "🇳🇱 Amsterdam" -> "NL". Null if [text] doesn't open with one.
String? countryCodeFromFlag(String text) {
  if (!startsWithFlagEmoji(text)) return null;
  final runes = text.runes.toList();
  return String.fromCharCode(runes[0] - _flagOffset) +
      String.fromCharCode(runes[1] - _flagOffset);
}
