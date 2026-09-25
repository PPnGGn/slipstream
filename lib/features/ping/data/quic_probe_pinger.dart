import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:pointycastle/digests/blake2b.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

/// Builds a QUIC long-header packet carrying a "greased" reserved
/// version (`0x?a?a?a?a`, RFC 9000/8701 convention: guaranteed to
/// never be assigned to a real version). Any QUIC implementation
/// (quic-go, used by hysteria2/sing-box/xray) that receives a
/// long-header packet with a version it doesn't support replies with
/// a Version Negotiation packet — a liveness signal that needs no
/// handshake, key or auth to elicit.
///
/// Padded to [quicProbeSize] bytes: quic-go silently drops
/// unknown-version long-header packets smaller than that, as an
/// amplification-attack guard (`MinUnknownVersionPacketSize`).
Uint8List buildQuicProbe(Random rng) {
  final packet = Uint8List(quicProbeSize);

  // Long header (bit 0x80) + fixed bit (0x40); the remaining 6 bits
  // are type-specific and irrelevant for an unsupported version.
  packet[0] = 0xC0 | rng.nextInt(0x40);

  // Greased version: each byte's low nibble is 0xa, high nibble random.
  for (var i = 1; i <= 4; i++) {
    packet[i] = (rng.nextInt(16) << 4) | 0x0a;
  }

  packet[5] = 8; // Destination Connection ID length
  _fillRandom(packet, 6, 8, rng);
  packet[14] = 8; // Source Connection ID length
  _fillRandom(packet, 15, 8, rng);

  // Padding — content doesn't matter, only the total datagram size.
  _fillRandom(packet, 23, packet.length - 23, rng);

  return packet;
}

void _fillRandom(Uint8List target, int offset, int length, Random rng) {
  for (var i = 0; i < length; i++) {
    target[offset + i] = rng.nextInt(256);
  }
}

const _salamanderSaltLen = 8;

/// Wraps [payload] the way hysteria2's "salamander" obfuscator does:
/// an 8-byte random salt followed by the payload XORed with
/// BLAKE2b-256(password ‖ salt), repeated over the key's 32 bytes.
/// Without this, a server configured with an obfs password never
/// even parses our probe as a QUIC packet.
Uint8List applySalamanderObfuscation(
  Uint8List payload,
  String password,
  Random rng,
) {
  final salt = Uint8List(_salamanderSaltLen);
  _fillRandom(salt, 0, salt.length, rng);
  final key = _salamanderKey(password, salt);

  final wire = Uint8List(_salamanderSaltLen + payload.length);
  wire.setRange(0, _salamanderSaltLen, salt);
  for (var i = 0; i < payload.length; i++) {
    wire[_salamanderSaltLen + i] = payload[i] ^ key[i % key.length];
  }
  return wire;
}

/// Inverse of [applySalamanderObfuscation] — kept for tests to verify
/// the wire format round-trips.
Uint8List removeSalamanderObfuscation(Uint8List wire, String password) {
  final salt = wire.sublist(0, _salamanderSaltLen);
  final key = _salamanderKey(password, salt);

  final payload = Uint8List(wire.length - _salamanderSaltLen);
  for (var i = 0; i < payload.length; i++) {
    payload[i] = wire[_salamanderSaltLen + i] ^ key[i % key.length];
  }
  return payload;
}

Uint8List _salamanderKey(String password, Uint8List salt) {
  final input = Uint8List.fromList([...utf8.encode(password), ...salt]);
  final digest = Blake2bDigest(digestSize: 32)..update(input, 0, input.length);
  final out = Uint8List(32);
  digest.doFinal(out, 0);
  return out;
}

/// Probes a UDP/QUIC endpoint (hysteria2) by sending one
/// [buildQuicProbe] datagram and waiting for any reply.
@LazySingleton(as: ServerPinger)
@Named('quic')
class QuicProbePinger implements ServerPinger {
  final _rng = Random();

  @override
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  }) async {
    RawDatagramSocket? socket;
    final stopwatch = Stopwatch()..start();
    try {
      final bindAddress = address.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;
      // NB: RawDatagramSocket.bind defaults ttl to 1 (meant for
      // multicast); a plain unicast probe with that TTL dies after
      // one router hop and every remote server would read as dead.
      socket = await RawDatagramSocket.bind(bindAddress, 0, ttl: 64);

      var probe = buildQuicProbe(_rng);
      final password = target.salamanderPassword;
      if (password != null && password.isNotEmpty) {
        probe = applySalamanderObfuscation(probe, password, _rng);
      }
      socket.send(probe, address, target.port);

      final completer = Completer<PingAttemptResult>();
      final subscription = socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        try {
          final datagram = socket!.receive();
          if (datagram == null) return;
          stopwatch.stop();
          completer.complete(
            PingAttemptSuccess(stopwatch.elapsedMicroseconds / 1000),
          );
        } on SocketException catch (e) {
          completer.complete(_classifySocketException(e));
        }
      });

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () => const PingAttemptTimedOut(),
      );
      await subscription.cancel();
      return result;
    } on SocketException catch (e) {
      return _classifySocketException(e);
    } finally {
      socket?.close();
    }
  }

  PingAttemptResult _classifySocketException(SocketException e) {
    final osError = e.osError;
    if (osError != null &&
        osConnectionRefusedErrorCodes.contains(osError.errorCode)) {
      return const PingAttemptRefused();
    }
    return PingAttemptSocketError(e);
  }
}
