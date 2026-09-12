import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Resolves the directory that holds geosite.dat / geoip.dat.
///
/// The native side owns this decision — Android hands back its internal files
/// dir, Apple the shared App Group container (the tunnel process only sees
/// that one). If the platform has no opinion (desktop), we fall back to
/// path_provider's application support dir, which already knows every desktop
/// OS — so adding desktop needs no work here.
@lazySingleton
class GeoPaths {
  GeoPaths(this._connection, this._talker);

  final VpnConnection _connection;
  final Talker _talker;
  String? _cached;

  Future<String> dir() async {
    if (_cached != null) return _cached!;

    String? path;
    try {
      path = await _connection.geoAssetDir();
    } catch (e) {
      _talker.warning('GeoPaths: native geoAssetDir() failed, using fallback: $e');
    }
    path ??=
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}geo';

    final directory = Directory(path);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    _cached = path;
    return path;
  }
}
