import 'dart:convert';
import 'dart:typed_data';

// Decodes a (possibly unpadded, standard or URL-safe) Base64 string, or null.
String? tryDecodeBase64(String s) {
  final bytes = tryDecodeBase64Bytes(s);
  if (bytes == null) return null;
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

Uint8List? tryDecodeBase64Bytes(String s) {
  var normalized = s.replaceAll(RegExp(r'\s+'), '');
  final padding = normalized.length % 4;
  if (padding != 0) normalized += '=' * (4 - padding);
  try {
    return base64.decode(normalized);
  } catch (_) {
    try {
      return base64Url.decode(normalized);
    } catch (_) {
      return null;
    }
  }
}
