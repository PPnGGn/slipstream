import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';

part 'split_tunnel_settings.freezed.dart';

@freezed
abstract class SplitTunnelSettings with _$SplitTunnelSettings {
  const SplitTunnelSettings._();

  const factory SplitTunnelSettings({
    @Default(false) bool enabled,
    @Default(SplitTunnelMode.bypass) SplitTunnelMode mode,
    @Default(<String>{}) Set<String> packages,
    @Default(false) bool includeSystem,
  }) = _SplitTunnelSettings;

  bool get isActive => enabled && packages.isNotEmpty;
}
