import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';

/// Texts of the Routing page and of its row in Settings, as pure functions:
/// the widgets only draw what these say, so they can be tested without one.

/// What the geo databases row says under its title.
String geoStatusText(GeoState state) => switch (state) {
  GeoAbsent() => 'Not downloaded',
  GeoChecking() => 'Checking for updates…',
  GeoDownloading(:final fraction) =>
    'Downloading… ${(fraction * 100).round()}%',
  GeoReady(:final tag, :final updatedAt) =>
    'Up to date · $tag · ${_date(updatedAt)}',
  GeoUpdateAvailable(:final latestTag) => 'Update available: $latestTag',
  GeoFailed(:final message) => message,
  _ => '',
};

/// The label of the geo databases button; null while there is nothing to tap.
String? geoActionLabel(GeoState state) => switch (state) {
  GeoAbsent() => 'Download',
  GeoReady() || GeoUpdateAvailable() => 'Update',
  GeoFailed() => 'Retry',
  _ => null,
};

/// The value of the Routing row in Settings: the two switches, the number of
/// custom rules (if any) and the state of the geo databases.
String routingSummary({
  required RuBypassMode ruBypass,
  required AdBlockMode adBlock,
  required int customRules,
  required GeoState geo,
}) {
  final parts = [
    ruBypass == RuBypassMode.bypassRu ? 'RU bypass' : 'RU bypass off',
    switch (adBlock) {
      AdBlockMode.off => 'ads off',
      AdBlockMode.basic => 'ads: basic',
      AdBlockMode.full => 'ads: full',
    },
    ?customRulesSummary(customRules),
    _geoSummary(geo),
  ];
  return parts.join(' · ');
}

String _geoSummary(GeoState state) => switch (state) {
  GeoAbsent() => 'geo databases not downloaded',
  GeoChecking() => 'checking geo databases…',
  GeoDownloading(:final fraction) =>
    'geo databases: ${(fraction * 100).round()}%',
  GeoReady() => 'geo databases up to date',
  GeoUpdateAvailable() => 'geo update available',
  GeoFailed() => 'geo download failed',
  _ => '',
};

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';
