import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';

@lazySingleton
class ClientIdentityStore {
  static const _realHwidKey = 'client_hwid_real';

  final SharedPreferences _prefs;

  ClientIdentityStore(this._prefs);

  /// The HWID saved by a previous launch, or null if there is none or the
  /// stored value is not one the panel would accept.
  String? loadRealHwid() {
    final value = _prefs.getString(_realHwidKey);
    if (value == null || !isValidHwid(value)) return null;
    return value;
  }

  Future<void> saveRealHwid(String hwid) =>
      _prefs.setString(_realHwidKey, hwid);
}
