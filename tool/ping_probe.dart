// ignore_for_file: avoid_print

import 'dart:io';

import 'package:slipstream/features/ping/data/quic_probe_pinger.dart';
import 'package:slipstream/features/ping/data/tcp_connect_pinger.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

const _attemptTimeout = Duration(milliseconds: attemptTimeoutMs);

Future<void> main() async {
  final tcp = TcpConnectPinger();
  final quic = QuicProbePinger();

  await probe(tcp, 'tcp live  ', '1.1.1.1', 80);
  await probe(tcp, 'tcp silent', '10.255.255.1', 81);
  await probe(tcp, 'tcp closed', '127.0.0.1', 54321);
  // 1.1.1.1:443 serves QUIC (HTTP/3) — good stand-in for a real
  // hysteria2 endpoint without needing one at hand.
  await probe(quic, 'quic live ', '1.1.1.1', 443);
  await probe(quic, 'quic silent', '10.255.255.1', 44300);
}

/// Runs one attempt and prints the label, wall-clock duration and the
/// result. Wall time answers the key probe question: does our own
/// ~2 s timeout fire, or does the OS-level one get there first?
Future<void> probe(ServerPinger pinger, String label, String host, int port) async {
  final address = InternetAddress.tryParse(host) ?? (await InternetAddress.lookup(host)).first;
  final target = PingTarget(host: host, port: port, probe: PingProbe.tcp);

  final stopwatch = Stopwatch()..start();
  final result = await pinger.ping(
    target: target,
    address: address,
    timeout: _attemptTimeout,
  );
  final wallMs = stopwatch.elapsedMicroseconds / 1000;

  switch (result) {
    case PingAttemptSuccess(:final durationMs):
      print(
        '$label $host:$port -> success, ${durationMs.toStringAsFixed(1)} ms '
        '(wall ${wallMs.toStringAsFixed(1)} ms)',
      );
    case PingAttemptTimedOut():
      print(
        '$label $host:$port -> timed out '
        '(wall ${wallMs.toStringAsFixed(1)} ms)',
      );
    case PingAttemptRefused():
      print(
        '$label $host:$port -> refused '
        '(wall ${wallMs.toStringAsFixed(1)} ms)',
      );
    case PingAttemptSocketError(:final error):
      print(
        '$label $host:$port -> socket error: $error '
        '(wall ${wallMs.toStringAsFixed(1)} ms)',
      );
  }
}
