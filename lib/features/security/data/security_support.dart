import 'package:flutter/foundation.dart';

/// The Security & tunnel page is Android only: the IPv6 switch and the kill
/// switch work through the Android VPN service. iOS keeps its own tunnel setup.
bool isSecuritySupported(TargetPlatform platform) =>
    platform == TargetPlatform.android;
