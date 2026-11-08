import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_exceptions.dart';
import 'package:slipstream/features/subscriptions/ui/add_subscription_toasts.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';
import 'package:slipstream/features/vpn/presentation/xray_logs_view.dart';
import 'package:slipstream/l10n/gen/app_localizations.dart';

import '../helpers/l10n.dart';

/// The pure text functions must read the translation, not a literal: with
/// another language the same call gives other words. Plurals are where
/// languages differ most (Russian has four forms, Chinese and Persian one).
void main() {
  group('plurals', () {
    test('Russian picks one / few / many by the number', () {
      expect(l10nRu.serverCountUpper(1), '1 СЕРВЕР');
      expect(l10nRu.serverCountUpper(2), '2 СЕРВЕРА');
      expect(l10nRu.serverCountUpper(5), '5 СЕРВЕРОВ');
      expect(l10nRu.serverCountUpper(21), '21 СЕРВЕР');
      expect(l10nRu.serverCountUpper(12), '12 СЕРВЕРОВ');
    });

    test('English has one form for one and one for the rest', () {
      expect(l10nEn.serverCountUpper(1), '1 SERVER');
      expect(l10nEn.serverCountUpper(0), '0 SERVERS');
      expect(l10nEn.serverCountUpper(2), '2 SERVERS');
    });

    test('Russian counts apps and rules in the right case', () {
      expect(l10nRu.rulesCount(1), '1 правило');
      expect(l10nRu.rulesCount(3), '3 правила');
      expect(l10nRu.rulesCount(11), '11 правил');
      expect(l10nRu.splitAppsCount(21), '21 приложение');
      expect(
        l10nRu.splitCounterBypassed(2, 5),
        '2 из 5 приложений идут в обход VPN',
      );
      expect(
        l10nRu.splitCounterProxied(0, 1),
        '0 из 1 приложения идут через VPN',
      );
    });

    test('Chinese and Persian have a single form', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final fa = lookupAppLocalizations(const Locale('fa'));
      expect(zh.serverCountUpper(1), '1 台服务器');
      expect(zh.serverCountUpper(7), '7 台服务器');
      expect(fa.serverCountUpper(1), '1 سرور');
      expect(fa.serverCountUpper(7), '7 سرور');
    });
  });

  test('the connection status follows the language', () {
    ConnectionStatusView view(AppLocalizations l10n) =>
        ConnectionStatusView.from(
          l10n: l10n,
          state: const VpnState.disconnected(),
          hasSubscriptions: false,
          selectedServer: null,
        );

    expect(view(l10nEn).title, 'No servers yet');
    expect(view(l10nRu).title, 'Серверов пока нет');
    expect(view(l10nRu).title, isNot(view(l10nEn).title));
  });

  test('a toast built in Russian is Russian, and keeps the HTTP code', () {
    final toast = addFailedToast(l10nRu, const HttpStatusException(502));
    expect(toast.title, 'Ошибка на сервере провайдера');
    expect(toast.subtitle, 'ПОПРОБУЙТЕ ПОЗЖЕ · HTTP 502');
  });

  test('the log status line counts lines in Russian', () {
    expect(
      logsStatusLine(l10nRu, lines: 3, tunnelUp: true, following: true),
      'СЛЕЖЕНИЕ · 3 СТРОКИ · ТУННЕЛЬ ВКЛЮЧЁН',
    );
  });
}
