import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/blake2b.dart';
import 'package:slipstream/features/ping/data/quic_probe_pinger.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

void main() {
  group('buildQuicProbe', () {
    test('is padded to quicProbeSize', () {
      final probe = buildQuicProbe(Random());
      expect(probe.length, quicProbeSize);
    });

    test('sets the long-header + fixed bits', () {
      final probe = buildQuicProbe(Random());
      expect(probe[0] & 0xC0, 0xC0);
    });

    test('version is a greased reserved value (0x?a?a?a?a)', () {
      final probe = buildQuicProbe(Random());
      for (var i = 1; i <= 4; i++) {
        expect(probe[i] & 0x0F, 0x0A);
      }
    });

    test('DCID and SCID are both 8 bytes', () {
      final probe = buildQuicProbe(Random());
      expect(probe[5], 8);
      expect(probe[14], 8);
    });
  });

  group('salamander obfuscation', () {
    test('adds an 8-byte salt prefix', () {
      final probe = buildQuicProbe(Random());
      final wire = applySalamanderObfuscation(probe, 'hunter2', Random());
      expect(wire.length, probe.length + 8);
    });

    test('round-trips back to the original probe', () {
      final probe = buildQuicProbe(Random());
      final wire = applySalamanderObfuscation(probe, 'hunter2', Random());
      final recovered = removeSalamanderObfuscation(wire, 'hunter2');
      expect(recovered, probe);
    });

    test('the wrong password fails to recover the original bytes', () {
      final probe = buildQuicProbe(Random());
      final wire = applySalamanderObfuscation(probe, 'hunter2', Random());
      final recovered = removeSalamanderObfuscation(wire, 'wrong');
      expect(recovered, isNot(probe));
    });
  });

  // Confirms this test file's own BLAKE2b-256 usage (and therefore
  // pointycastle's) matches the well-known reference vector, before
  // trusting the round-trip tests above to catch a wiring mistake.
  test('BLAKE2b-256 matches the known test vector for "abc"', () {
    final digest = Blake2bDigest(digestSize: 32)
      ..update(Uint8List.fromList(utf8.encode('abc')), 0, 3);
    final out = Uint8List(32);
    digest.doFinal(out, 0);

    final hex = out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex, 'bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319');
  });
}
