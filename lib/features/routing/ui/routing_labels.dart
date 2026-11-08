import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Texts of the Routing page and of its row in Settings, as pure functions:
/// the widgets only draw what these say, so they can be tested without one.

/// What the geo databases row says under its title.
String geoStatusText(AppLocalizations l10n, GeoState state) => switch (state) {
  GeoAbsent() => l10n.geoNotDownloaded,
  GeoChecking() => l10n.geoChecking,
  GeoDownloading(:final fraction) => l10n.geoDownloading(
    (fraction * 100).round(),
  ),
  GeoReady(:final tag, :final updatedAt) => l10n.geoUpToDate(
    tag,
    _date(updatedAt),
  ),
  GeoUpdateAvailable(:final latestTag) => l10n.geoUpdateAvailable(latestTag),
  GeoFailed(:final message) => message,
  _ => '',
};

/// The label of the geo databases button; null while there is nothing to tap.
String? geoActionLabel(AppLocalizations l10n, GeoState state) =>
    switch (state) {
      GeoAbsent() => l10n.geoActionDownload,
      GeoReady() || GeoUpdateAvailable() => l10n.geoActionUpdate,
      GeoFailed() => l10n.commonRetry,
      _ => null,
    };

/// The value of the Routing row in Settings: the two switches, the number of
/// custom rules (if any) and the state of the geo databases.
String routingSummary(
  AppLocalizations l10n, {
  required RuBypassMode ruBypass,
  required AdBlockMode adBlock,
  required int customRules,
  required GeoState geo,
}) {
  final parts = [
    ruBypass == RuBypassMode.bypassRu
        ? l10n.ruBypassTitle
        : l10n.summaryRuBypassOff,
    switch (adBlock) {
      AdBlockMode.off => l10n.summaryAdsOff,
      AdBlockMode.basic => l10n.summaryAdsBasic,
      AdBlockMode.full => l10n.summaryAdsFull,
    },
    ?customRulesSummary(l10n, customRules),
    _geoSummary(l10n, geo),
  ];
  return parts.join(' · ');
}

String _geoSummary(AppLocalizations l10n, GeoState state) => switch (state) {
  GeoAbsent() => l10n.summaryGeoAbsent,
  GeoChecking() => l10n.summaryGeoChecking,
  GeoDownloading(:final fraction) => l10n.summaryGeoDownloading(
    (fraction * 100).round(),
  ),
  GeoReady() => l10n.summaryGeoReady,
  GeoUpdateAvailable() => l10n.summaryGeoUpdate,
  GeoFailed() => l10n.summaryGeoFailed,
  _ => '',
};

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';
