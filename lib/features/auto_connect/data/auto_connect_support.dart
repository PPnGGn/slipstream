import 'package:flutter/foundation.dart';

/// Android only. On iOS starting the tunnel saves the VPN configuration, and
/// the system would ask for permission again on every launch.
bool isAutoConnectSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android;
