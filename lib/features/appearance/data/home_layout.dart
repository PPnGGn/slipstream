/// How the home screen shows the connection (Settings → Appearance →
/// Connection style). Purely a UI preference: switching it never touches
/// the tunnel, the selected server or the timer.
enum HomeLayout {
  /// Card with the big connect ring above the server list.
  classic,

  /// Slim bar with a switch at the bottom; Add / Paste / Scan QR under the list.
  compact;

  static HomeLayout fromName(String? name) => HomeLayout.values.firstWhere(
    (l) => l.name == name,
    orElse: () => HomeLayout.classic,
  );
}
