enum SplitTunnelMode {
  proxy,
  bypass;

  static SplitTunnelMode fromName(String? name) => SplitTunnelMode.values
      .firstWhere((m) => m.name == name, orElse: () => SplitTunnelMode.bypass);
}
