/// Whether the home screen shows a live readout of xray-core's memory
/// footprint (a line next to the connection card: `23 MB · Normal`, see
/// `MemoryMonitorLine`). Purely a UI preference — it never affects the tunnel itself, so
/// unlike the routing toggles it takes effect immediately, no reconnect.
enum MemoryMonitorMode {
  off,
  on;

  bool get enabled => this == MemoryMonitorMode.on;

  static MemoryMonitorMode fromName(String? name) => MemoryMonitorMode.values
      .firstWhere((m) => m.name == name, orElse: () => MemoryMonitorMode.off);
}
