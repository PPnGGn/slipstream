import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/data/real_delay_api.g.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// What the request goes to through the server: 204 with no body, served by
/// Google from everywhere, so the time is the way through the server and not
/// the weight of a page.
const realDelayUrl = 'https://www.gstatic.com/generate_204';

/// One limit for the whole check, the start of xray inside the core included.
const realDelayTimeoutMs = 8000;

/// The answer of one check: a number or a reason, never both.
class RealDelayOutcome {
  const RealDelayOutcome.measured(int this.latencyMs) : failure = null;
  const RealDelayOutcome.failed(RealDelayFailure this.failure)
    : latencyMs = null;

  final int? latencyMs;
  final RealDelayFailure? failure;
}

/// Maps what the native side answered. The core says "timed out" for a
/// check that ran out of time (see core/measure.go); everything else, and an
/// answer with nothing in it, is a failure of another kind.
RealDelayOutcome outcomeOfResult(RealDelayResult result) {
  final latency = result.latencyMs;
  if (latency != null) return RealDelayOutcome.measured(latency);
  final error = result.error ?? '';
  return RealDelayOutcome.failed(
    error.contains('timed out')
        ? RealDelayFailure.timeout
        : RealDelayFailure.other,
  );
}

/// Measures one server. An interface so the cubit can be tested without a
/// platform channel.
abstract interface class RealDelayClient {
  Future<RealDelayOutcome> measure(VpnServer server);
}

/// The Pigeon bridge to the core (Android). The config goes through the same
/// gates a start does (routing policy, geo, Fragment and Noise), so the
/// number is that of the connection the user would get.
@LazySingleton(as: RealDelayClient)
class PlatformRealDelayClient implements RealDelayClient {
  PlatformRealDelayClient(this._repository, this._talker);

  final VpnRepository _repository;
  final Talker _talker;
  final _api = RealDelayApi();

  @override
  Future<RealDelayOutcome> measure(VpnServer server) async {
    if (!Platform.isAndroid) {
      return const RealDelayOutcome.failed(RealDelayFailure.other);
    }
    try {
      final message = await _repository.buildConfigMessage(server);
      final result = await _api.measure(
        RealDelayRequest(
          configJson: message.configJson,
          // "" keeps the folder a running session set (core/measure.go).
          geoAssetDir: message.geoAssetDir ?? '',
          url: realDelayUrl,
          timeoutMs: realDelayTimeoutMs,
        ),
      );
      final outcome = outcomeOfResult(result);
      // The config is not logged, and neither is the core's text: it may carry
      // an address from it.
      _talker.debug(
        'Real delay of ${server.title}: '
        '${outcome.latencyMs != null ? '${outcome.latencyMs} ms' : outcome.failure!.name}',
      );
      return outcome;
    } on MissingPluginException {
      return const RealDelayOutcome.failed(RealDelayFailure.other);
    }
  }
}
