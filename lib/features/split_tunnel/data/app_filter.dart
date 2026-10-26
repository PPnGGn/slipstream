import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

List<InstalledAppMessage> visibleApps(
  List<InstalledAppMessage> apps,
  SplitTunnelSettings settings,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  return apps.where((app) {
    final shownAsSystem =
        !app.isSystem ||
        settings.includeSystem ||
        settings.packages.contains(app.packageName);
    if (!shownAsSystem) return false;
    if (normalized.isEmpty) return true;
    return app.label.toLowerCase().contains(normalized) ||
        app.packageName.toLowerCase().contains(normalized);
  }).toList();
}
