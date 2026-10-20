import 'package:flutter/foundation.dart';

// The camera scanner plugin only exists for Android and iOS.
bool isQrScanSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;

// The camera reports a detection many times per second while a QR code stays
// in the frame. A session hands out the first usable value exactly once.
class QrScanSession {
  bool _done = false;

  String? accept(Iterable<String?> rawValues) {
    if (_done) return null;
    for (final raw in rawValues) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) continue;
      _done = true;
      return value;
    }
    return null;
  }
}
