import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';

/// Keeps the DNS choices in SharedPreferences, one key per field. A missing or
/// unrecognised value reads as that field's default.
@lazySingleton
class DnsSettingsStore {
  static const _remoteKey = 'dns_remote';
  static const _directKey = 'dns_direct';
  static const _fakeDnsKey = 'dns_fake_dns';

  final SharedPreferences _prefs;

  DnsSettingsStore(this._prefs);

  DnsSettings load() => DnsSettings(
    remote: RemoteDns.fromName(_prefs.getString(_remoteKey)),
    direct: DirectDns.fromName(_prefs.getString(_directKey)),
    fakeDns: _prefs.getBool(_fakeDnsKey) ?? false,
  );

  Future<void> save(DnsSettings settings) async {
    await _prefs.setString(_remoteKey, settings.remote.name);
    await _prefs.setString(_directKey, settings.direct.name);
    await _prefs.setBool(_fakeDnsKey, settings.fakeDns);
  }
}
