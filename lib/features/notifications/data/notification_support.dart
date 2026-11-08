import 'package:flutter/foundation.dart';

/// The connection alerts come from the Android VPN service. iOS keeps its own
/// tunnel and shows no such alerts (see next-releases.md, ideas without a date).
bool isNotificationsSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android;
