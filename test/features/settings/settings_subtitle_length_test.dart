import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/l10n/gen/app_localizations.dart';

/// A settings row is 56 tall and its subtitle is one line, cut with an
/// ellipsis (SettingsRow). So every subtitle has to be short enough to be read
/// whole on a phone: about 36 letters in a row with a switch (a Chinese
/// character counts as two). The texts that carry a value in the row (a number,
/// a range) are measured with a typical one.
void main() {
  final subtitles = <String, String Function(AppLocalizations)>{
    'autoConnectOn': (l) => l.autoConnectOn,
    'autoConnectOff': (l) => l.autoConnectOff,
    'settingsSubscriptionsSubtitle': (l) => l.settingsSubscriptionsSubtitle,
    'settingsSplitSubtitle': (l) => l.settingsSplitSubtitle,
    'settingsSecuritySubtitle': (l) => l.settingsSecuritySubtitle,
    'settingsBackupSubtitle': (l) => l.settingsBackupSubtitle,
    'settingsNotificationsSubtitle': (l) => l.settingsNotificationsSubtitle,
    'settingsMemoryIosSubtitle': (l) => l.settingsMemoryIosSubtitle,
    'settingsMemorySubtitle': (l) => l.settingsMemorySubtitle,
    'settingsLogsSubtitle': (l) => l.settingsLogsSubtitle,
    'killSwitchOn': (l) => l.killSwitchOn,
    'killSwitchOff': (l) => l.killSwitchOff,
    'ipv6On': (l) => l.ipv6On,
    'ipv6Off': (l) => l.ipv6Off,
    'dnsSystemSubtitle': (l) => l.dnsSystemSubtitle,
    'fakeDnsOn': (l) => l.fakeDnsOn,
    'fakeDnsOff': (l) => l.fakeDnsOff,
    'ruleAddSubtitle': (l) => l.ruleAddSubtitle,
    'pingOnLaunchSubtitle': (l) => l.pingOnLaunchSubtitle,
    'pingSortSubtitle': (l) => l.pingSortSubtitle,
    'pingDisplaySubtitle': (l) => l.pingDisplaySubtitle,
    'splitSystemSubtitle': (l) => l.splitSystemSubtitle,
    'fragmentOff': (l) => l.fragmentOff,
    'fragmentOn': (l) => l.fragmentOn('tlshello', '100-200', '10-20'),
    'noiseOff': (l) => l.noiseOff,
    'noiseOn': (l) => l.noiseOn('10-20', '10-16'),
    'notifyTrafficBlockedSubtitle': (l) => l.notifyTrafficBlockedSubtitle,
    'notifyStartFailedSubtitle': (l) => l.notifyStartFailedSubtitle,
    'notifyRevokedSubtitle': (l) => l.notifyRevokedSubtitle,
    'notifyTunnelLostSubtitle': (l) => l.notifyTunnelLostSubtitle,
    'notifySubscriptionFailedSubtitle': (l) =>
        l.notifySubscriptionFailedSubtitle,
    'notifySubscriptionLimitsSubtitle': (l) =>
        l.notifySubscriptionLimitsSubtitle,
    'versionSubtitleTap': (l) => l.versionSubtitleTap('26.11.9'),
  };

  // Width in letters: a Chinese character is as wide as two letters.
  int width(String text) =>
      text.runes.fold(0, (sum, rune) => sum + (rune >= 0x2E80 ? 2 : 1));

  for (final code in ['en', 'ru', 'fa', 'zh']) {
    test('every settings subtitle in "$code" fits one line', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final tooLong = <String>[
        for (final MapEntry(:key, :value) in subtitles.entries)
          if (width(value(l10n)) > 36) '$key (${width(value(l10n))}): ${value(l10n)}',
      ];

      expect(tooLong, isEmpty);
    });
  }

  test('the split tunnel row on Settings reads as a per-app proxy', () {
    expect(
      lookupAppLocalizations(const Locale('en')).settingsSplitSubtitle,
      'Per-app proxy',
    );
    expect(
      lookupAppLocalizations(const Locale('ru')).settingsSplitSubtitle,
      'Прокси по приложениям',
    );
  });
}
