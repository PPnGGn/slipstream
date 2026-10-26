import 'package:flutter/foundation.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';

@immutable
class SplitTunnelSettings {
  const SplitTunnelSettings({
    this.enabled = false,
    this.mode = SplitTunnelMode.bypass,
    this.packages = const {},
    this.includeSystem = false,
  });

  final bool enabled;
  final SplitTunnelMode mode;
  final Set<String> packages;
  final bool includeSystem;

  bool get isActive => enabled && packages.isNotEmpty;

  SplitTunnelSettings copyWith({
    bool? enabled,
    SplitTunnelMode? mode,
    Set<String>? packages,
    bool? includeSystem,
  }) => SplitTunnelSettings(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    packages: packages ?? this.packages,
    includeSystem: includeSystem ?? this.includeSystem,
  );

  @override
  bool operator ==(Object other) =>
      other is SplitTunnelSettings &&
      other.enabled == enabled &&
      other.mode == mode &&
      other.includeSystem == includeSystem &&
      setEquals(other.packages, packages);

  @override
  int get hashCode => Object.hash(
    enabled,
    mode,
    includeSystem,
    Object.hashAllUnordered(packages),
  );
}
