import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

// Salt for the device ID hash. NEVER change it: every user's HWID is derived
// from it, so a new salt makes the panel see every device as a new one.
const _hwidSalt = 'slipstream_hwid_';

// Same pattern the Remnawave panel applies to the `x-hwid` header. A value
// that does not match is silently ignored by the panel.
final _hwidPattern = RegExp(r'^[a-zA-Z0-9=-]{10,64}$');

bool isValidHwid(String value) => _hwidPattern.hasMatch(value);

/// Turns a raw platform device ID into a stable HWID in UUID shape
/// (8-4-4-4-12, lowercase hex). The raw ID never leaves the device.
String hwidFromDeviceId(String deviceId) {
  final hex = sha256.convert(utf8.encode('$_hwidSalt$deviceId')).toString();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20, 32),
  ].join('-');
}

/// Fallback for devices that expose no ID: a random UUID v4. The caller must
/// persist it, otherwise the panel sees a new device on every launch.
String randomHwid() => const Uuid().v4();
