import 'package:injectable/injectable.dart';
import 'package:slipstream/features/client_identity/data/client_identity.dart';
import 'package:slipstream/features/client_identity/data/client_identity_store.dart';
import 'package:slipstream/features/client_identity/data/device_info_api.g.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';
import 'package:talker_flutter/talker_flutter.dart';

@lazySingleton
class ClientIdentityRepository {
  /// Panels match on the `Happ/` prefix, the version part is free.
  static const defaultUserAgent = 'Happ/4.7.1';

  final ClientIdentityStore _store;
  final DeviceInfoApi _deviceApi;
  final Talker _talker;

  ClientIdentityRepository(this._store, this._deviceApi, this._talker);

  // The Future is cached, not its result: concurrent callers must share one
  // native call (and one random fallback HWID).
  Future<ClientIdentity>? _identity;

  /// What to tell the panel about this device. Computed once per launch.
  Future<ClientIdentity> current() => _identity ??= _load();

  Future<ClientIdentity> _load() async {
    final info = await _readDeviceInfo();
    final hwid = await _resolveHwid(info?.deviceId);
    return ClientIdentity(
      userAgent: defaultUserAgent,
      hwid: hwid,
      deviceOs: info?.os,
      osVersion: info?.osVersion,
      deviceModel: info?.model,
    );
  }

  // A native failure is treated as "no device info": headers are best effort
  // and must never stop a subscription from loading.
  Future<DeviceInfoMessage?> _readDeviceInfo() async {
    try {
      return await _deviceApi.getDeviceInfo();
    } catch (e) {
      _talker.warning('Identity: device info unavailable: $e');
      return null;
    }
  }

  // The device ID wins over the stored value: Android Auto Backup can carry
  // prefs to a new phone, and that phone must not reuse the old HWID.
  Future<String> _resolveHwid(String? deviceId) async {
    final stored = _store.loadRealHwid();
    final hwid = (deviceId != null && deviceId.isNotEmpty)
        ? hwidFromDeviceId(deviceId)
        : stored ?? randomHwid();
    if (hwid != stored) await _save(hwid);
    // Logs can be shared with other people, so never print the whole HWID.
    _talker.info('Identity: HWID ${hwid.substring(0, 4)}…');
    return hwid;
  }

  // _identity caches this Future for good, so a failed save must not fail it:
  // the HWID is still valid for this launch, it is just recomputed next time.
  Future<void> _save(String hwid) async {
    try {
      await _store.saveRealHwid(hwid);
    } catch (e) {
      _talker.warning('Identity: could not save HWID: $e');
    }
  }
}
