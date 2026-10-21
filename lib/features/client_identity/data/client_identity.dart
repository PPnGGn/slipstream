const _maxHeaderValueLength = 256;

/// What this client tells a subscription panel about itself.
class ClientIdentity {
  const ClientIdentity({
    required this.userAgent,
    required this.hwid,
    this.deviceOs,
    this.osVersion,
    this.deviceModel,
  });

  final String userAgent;
  final String hwid;
  final String? deviceOs;
  final String? osVersion;
  final String? deviceModel;

  /// Headers for a subscription request. Every value is cleaned, and a header
  /// that is null or empty after cleaning is left out instead of sent blank
  /// (the panel would store a blank OS version otherwise).
  Map<String, String> toHeaders() {
    final raw = <String, String?>{
      'User-Agent': userAgent,
      'x-hwid': hwid,
      'x-device-os': deviceOs,
      'x-ver-os': osVersion,
      'x-device-model': deviceModel,
    };
    final headers = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value == null) continue;
      final clean = sanitizeHeaderValue(value);
      if (clean.isNotEmpty) headers[entry.key] = clean;
    }
    return headers;
  }
}

/// Makes a value safe to send as an HTTP header: keeps only printable ASCII
/// (0x20-0x7E), cuts it to 256 characters and trims the spaces around it.
/// Meant for data that comes from the system (device model, OS version);
/// user input must be rejected with a message instead of silently cleaned.
String sanitizeHeaderValue(String value) {
  final printable = String.fromCharCodes(
    value.runes.where((r) => r >= 0x20 && r <= 0x7E),
  );
  final cut = printable.length > _maxHeaderValueLength
      ? printable.substring(0, _maxHeaderValueLength)
      : printable;
  return cut.trim();
}
