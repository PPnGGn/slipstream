/// Whether the home screen shows a live readout of xray-core's memory
/// footprint (a chip on the connection card, next to the protocol/traffic
/// chips). Purely a UI preference — it never affects the tunnel itself, so
/// unlike the routing toggles it takes effect immediately, no reconnect.
enum MemoryMonitorMode {
  off,
  on;

  bool get enabled => this == MemoryMonitorMode.on;

  static MemoryMonitorMode fromName(String? name) =>
      MemoryMonitorMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => MemoryMonitorMode.off,
      );
}
