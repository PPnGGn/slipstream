import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/data/quic_probe_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

/// A datagram socket whose [onSend] decides what sending does: answer, fail
/// by throwing, or fail the way dart:io does for an OS error on a socket that
/// is already bound: as an error event on the socket's stream.
class _FakeDatagramSocket extends Stream<RawSocketEvent>
    implements RawDatagramSocket {
  _FakeDatagramSocket(this._onSend);

  final void Function(_FakeDatagramSocket socket) _onSend;
  final _events = StreamController<RawSocketEvent>();
  Datagram? reply;
  bool closed = false;

  void fail(SocketException e) => _events.addError(e);

  void answer() {
    reply = Datagram(Uint8List(8), InternetAddress.loopbackIPv4, 443);
    _events.add(RawSocketEvent.read);
  }

  @override
  int send(List<int> buffer, InternetAddress address, int port) {
    _onSend(this);
    return buffer.length;
  }

  @override
  Datagram? receive() {
    final datagram = reply;
    reply = null;
    return datagram;
  }

  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _events.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  void close() {
    closed = true;
    _events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SocketException _sendFailed(int errno, String text) => SocketException(
  'Send failed',
  osError: OSError(text, errno),
  address: InternetAddress.anyIPv4,
  port: 0,
);

void main() {
  const target = PingTarget(
    host: 'example.test',
    port: 443,
    probe: PingProbe.quic,
  );
  final address = InternetAddress('192.0.2.1');

  late _FakeDatagramSocket socket;

  /// Runs one ping on [socket], and reports every error the zone did not
  /// handle: in the app such an error reaches the framework as "Unhandled
  /// Exception".
  Future<(PingAttemptResult, List<Object>, Duration)> pingOnce(
    void Function(_FakeDatagramSocket) onSend, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    socket = _FakeDatagramSocket(onSend);
    final pinger = QuicProbePinger(
      bind: (host, port, {ttl = 1}) async => socket,
    );
    final uncaught = <Object>[];
    final watch = Stopwatch()..start();
    final result = Completer<PingAttemptResult>();
    runZonedGuarded(
      () => pinger
          .ping(target: target, address: address, timeout: timeout)
          .then(result.complete),
      (error, stack) => uncaught.add(error),
    );
    final r = await result.future;
    // Let a stray error event reach the zone before looking.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return (r, uncaught, watch.elapsed);
  }

  test('a reply is a success', () async {
    final (result, uncaught, _) = await pingOnce((s) => s.answer());

    expect(result, isA<PingAttemptSuccess>());
    expect(uncaught, isEmpty);
    expect(socket.closed, isTrue);
  });

  test('silence is a timeout', () async {
    final (result, uncaught, _) = await pingOnce(
      (s) {},
      timeout: const Duration(milliseconds: 100),
    );

    expect(result, isA<PingAttemptTimedOut>());
    expect(uncaught, isEmpty);
    expect(socket.closed, isTrue);
  });

  // The case of the phone: the OS refuses the send ("Operation not
  // permitted") while the network is not up, and dart:io reports that as an
  // error on the stream of the socket, which the pinger listens to.
  test('a failed send reported on the stream is a socket error, at once, and '
      'no unhandled exception', () async {
    final (result, uncaught, took) = await pingOnce(
      (s) => s.fail(_sendFailed(1, 'Operation not permitted')),
    );

    expect(result, isA<PingAttemptSocketError>());
    expect(uncaught, isEmpty, reason: 'the error escaped the pinger');
    expect(
      took,
      lessThan(const Duration(seconds: 2)),
      reason: 'it waited for the timeout instead of giving up',
    );
    expect(socket.closed, isTrue);
  });

  test('a refusal reported on the stream is a refusal', () async {
    final (result, uncaught, _) = await pingOnce(
      (s) => s.fail(
        _sendFailed(osConnectionRefusedErrorCodes.first, 'Connection refused'),
      ),
    );

    expect(result, isA<PingAttemptRefused>());
    expect(uncaught, isEmpty);
  });

  test('a send that throws is a socket error', () async {
    final (result, uncaught, _) = await pingOnce(
      (s) => throw _sendFailed(1, 'Operation not permitted'),
    );

    expect(result, isA<PingAttemptSocketError>());
    expect(uncaught, isEmpty);
    expect(socket.closed, isTrue);
  });

  test('a socket that cannot be bound is a socket error', () async {
    final pinger = QuicProbePinger(
      bind: (host, port, {ttl = 1}) async =>
          throw _sendFailed(101, 'Network is unreachable'),
    );

    final result = await pinger.ping(
      target: target,
      address: address,
      timeout: const Duration(milliseconds: 100),
    );

    expect(result, isA<PingAttemptSocketError>());
  });

  test('a late error after the reply does not change the result', () async {
    final (result, uncaught, _) = await pingOnce((s) {
      s.answer();
      s.fail(_sendFailed(1, 'Operation not permitted'));
    });

    expect(result, isA<PingAttemptSuccess>());
    expect(uncaught, isEmpty);
  });
}
