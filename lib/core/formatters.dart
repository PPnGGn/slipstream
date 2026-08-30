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

/// Turns a 2-letter country code into its flag emoji, e.g. "NL" -> "🇳🇱".
String countryFlag(String code) {
  if (code.length != 2) return '🏳️';
  final upper = code.toUpperCase();
  final first = upper.codeUnitAt(0) + 0x1F1A5;
  final second = upper.codeUnitAt(1) + 0x1F1A5;
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// True if [text] already opens with a flag emoji (a pair of regional
/// indicator symbols), so callers don't double up with their own flag.
bool startsWithFlagEmoji(String text) {
  final runes = text.runes.toList();
  if (runes.length < 2) return false;
  bool isRegionalIndicator(int r) => r >= 0x1F1E6 && r <= 0x1F1FF;
  return isRegionalIndicator(runes[0]) && isRegionalIndicator(runes[1]);
}
