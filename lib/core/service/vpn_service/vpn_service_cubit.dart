import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/result.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';
import 'package:slipstream/features/vpn/data/vpn_session_store.dart';

part 'vpn_service_state.dart';
part 'vpn_service_cubit.freezed.dart';

@lazySingleton
class VpnServiceCubit extends Cubit<VpnState> {
  VpnServiceCubit({
    required VpnRepository repository,
    required VpnSessionStore sessionStore,
    required Talker talker,
  }) : _repository = repository,
       _sessionStore = sessionStore,
       _talker = talker,
       super(const VpnState.disconnected()) {
    _currentServer = _sessionStore.load();
    _statusSubscription = _repository.status.listen(_onNativeStatus);
    _trafficSubscription = _repository.traffic.listen(_onTraffic);
    _lifecycleListener = AppLifecycleListener(onResume: _syncStatus);
    _syncStatus();
  }
  static const _connectTimeout = Duration(seconds: 15);
  static const _nativeStartTimeout = Duration(seconds: 45);
  final VpnRepository _repository;
  final VpnSessionStore _sessionStore;
  final Talker _talker;

  late final StreamSubscription<VpnStatusMessage> _statusSubscription;
  late final StreamSubscription<VpnTrafficMessage> _trafficSubscription;
  late final AppLifecycleListener _lifecycleListener;
  VpnServer? _currentServer;
  DateTime? _connectedAt;
  Timer? _connectTimer;
  VpnServer? _pendingServer;

  Future<void> toggle(VpnServer? server) async {
    switch (state) {
      case _Connected() || _Connecting():
        await disconnect();
      case _Disconnecting():
        break;
      default:
        if (server != null) await connect(server);
    }
  }

  Future<void> connect(VpnServer server) async {
    switch (state) {
      case _Connected() || _Connecting():
        final activeId = _currentServer?.id;
        if (activeId == server.id) {
          _talker.debug('Cubit: connect ignored, already on ${server.id}');
          return;
        }
        _talker.debug('Cubit: switching server $activeId -> ${server.id}');
        _pendingServer = server;
        await _requestStop();
      case _Disconnecting():
        _talker.debug(
          'Cubit: queued switch to ${server.id} while disconnecting',
        );
        _pendingServer = server;
      default:
        await _startConnection(server);
    }
  }

  void switchServerIfActive(VpnServer server) {
    final isActive = state is _Connected || state is _Connecting;
    if (isActive) unawaited(connect(server));
  }

  Future<void> _startConnection(VpnServer server) async {
    _talker.debug('Cubit: connecting to ${server.title}');
    _currentServer = server;
    unawaited(_sessionStore.save(server));
    emit(const VpnState.connecting());
    _startConnectTimeout(_nativeStartTimeout);

    final result = await _repository.start(server);
    switch (result) {
      case Success():
        _talker.info('Cubit: core started, waiting for tunnel confirmation');
        _startConnectTimeout(_connectTimeout);
      case Failure(:final message):
        _talker.error('Cubit: connect failed -> $message');
        _connectTimer?.cancel();
        _pendingServer = null;
        _clearSession();
        emit(VpnState.error(message));
    }
  }

  Future<void> disconnect() async {
    _pendingServer = null;
    await _requestStop();
  }

  Future<void> _requestStop() async {
    if (state is _Disconnected || state is _Disconnecting) {
      _talker.debug('Cubit: disconnect ignored, state: $state');
      return;
    }

    _talker.debug('Cubit: disconnecting VPN');
    _connectTimer?.cancel();
    emit(const VpnState.disconnecting());

    final result = await _repository.stop();
    if (result case Failure(:final message)) {
      _talker.error('Cubit: disconnect failed -> $message');
      _pendingServer = null;
      emit(VpnState.error(message));
    }
  }

  Future<void> _syncStatus() async {
    try {
      final status = await _repository.getStatus();
      _talker.debug('Cubit: getStatus on start -> ${status.status}');

      final server = _currentServer;
      if (state is _Connecting &&
          status.status == VpnStatus.disconnected &&
          server != null) {
        _talker.warning(
          'Cubit: resumed mid-connect but native is disconnected, retrying ${server.id}',
        );
        unawaited(_startConnection(server));
        return;
      }

      _onNativeStatus(status);
    } catch (e, st) {
      _talker.handle(e, st, 'Cubit: getStatus failed');
    }
  }

  void _onNativeStatus(VpnStatusMessage message) {
    _talker.debug('Cubit: native status -> ${message.status}');
    switch (message.status) {
      case VpnStatus.connecting:
        if (state is! _Connecting) emit(const VpnState.connecting());
        _startConnectTimeout();
      case VpnStatus.connected:
        _connectTimer?.cancel();
        final server = _currentServer ?? _sessionStore.load();
        if (server == null) {
          _talker.warning('Cubit: connected from native with no known server');
          return;
        }
        _currentServer = server;

        final connectedAtMs = message.connectedAtEpochMs;
        _connectedAt = connectedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(connectedAtMs)
            : (_connectedAt ?? DateTime.now());
        emit(VpnState.connected(server, connectedAt: _connectedAt!));
      case VpnStatus.disconnecting:
        _connectTimer?.cancel();
        emit(const VpnState.disconnecting());
      case VpnStatus.disconnected:
        _connectTimer?.cancel();
        _clearSession();
        emit(const VpnState.disconnected());
        final pending = _pendingServer;
        if (pending != null) {
          _pendingServer = null;
          unawaited(_startConnection(pending));
        }
      case VpnStatus.error:
        _connectTimer?.cancel();
        _pendingServer = null;
        _clearSession();
        emit(VpnState.error(message.error ?? 'VPN error'));
    }
  }

  void _onTraffic(VpnTrafficMessage traffic) {
    final current = state;
    if (current is _Connected) {
      emit(
        current.copyWith(
          uplinkBytes: traffic.uplinkBytes,
          downlinkBytes: traffic.downlinkBytes,
        ),
      );
    }
  }

  void _startConnectTimeout([Duration timeout = _connectTimeout]) {
    _connectTimer?.cancel();
    _connectTimer = Timer(timeout, () {
      if (state is! _Connecting) return;
      _talker.error('Cubit: timed out waiting for tunnel confirmation');
      _pendingServer = null;
      _clearSession();
      unawaited(_repository.stop());
      emit(const VpnState.error('Tunnel did not come up in time'));
    });
  }

  void _clearSession() {
    _currentServer = null;
    _connectedAt = null;
  }

  @override
  Future<void> close() {
    _connectTimer?.cancel();
    _statusSubscription.cancel();
    _trafficSubscription.cancel();
    _lifecycleListener.dispose();
    return super.close();
  }
}
