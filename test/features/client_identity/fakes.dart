import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/client_identity/data/client_identity_repository.dart';
import 'package:slipstream/features/client_identity/data/client_identity_store.dart';
import 'package:slipstream/features/client_identity/data/device_info_api.g.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// A real repository on empty mock prefs, for tests of code that depends on it.
Future<ClientIdentityRepository> identityRepositoryWith(
  FakeDeviceInfoApi api,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ClientIdentityRepository(ClientIdentityStore(prefs), api, Talker());
}

/// Extends (not implements) the generated class: it carries Pigeon's own
/// fields, and `implements` would force us to override all of them.
class FakeDeviceInfoApi extends DeviceInfoApi {
  FakeDeviceInfoApi({
    String? deviceId,
    String os = 'Android',
    String osVersion = '14',
    String model = 'Pixel 8',
    this.error,
  }) : message = DeviceInfoMessage(
         deviceId: deviceId,
         os: os,
         osVersion: osVersion,
         model: model,
       );

  final DeviceInfoMessage message;

  /// When set, getDeviceInfo throws it instead of answering.
  final Object? error;

  int calls = 0;

  @override
  Future<DeviceInfoMessage> getDeviceInfo() async {
    calls++;
    // A real channel call is asynchronous, so concurrent callers overlap.
    await Future<void>.delayed(Duration.zero);
    final failure = error;
    if (failure != null) throw failure;
    return message;
  }
}

/// A store whose writes fail, like a prefs file that cannot be written.
class FailingWriteStore extends ClientIdentityStore {
  FailingWriteStore(super.prefs);

  @override
  Future<void> saveRealHwid(String hwid) =>
      Future.error(StateError('disk is full'));
}
