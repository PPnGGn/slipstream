import 'package:flutter/foundation.dart';

/// Fake DNS is Android only. It hands out made-up addresses from a pool and
/// remembers which name each one stands for. On iOS the tunnel extension has a
/// 50 MB memory cap, and the iOS tunnel is frozen and not verified anyway.
bool isFakeDnsSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android;
