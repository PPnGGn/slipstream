import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/toast/toast_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(
    WidgetTester tester,
    ToastMessage message, {
    AppThemeMode mode = AppThemeMode.dark,
    VoidCallback? onTap,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    )..setMode(mode);
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: cubit));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToastCard(message: message, onTap: onTap ?? () {}),
          ),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  const plain = ToastMessage(id: 1, title: 'Logs copied', kind: .success);
  const detailed = ToastMessage(
    id: 2,
    title: 'Subscription updated',
    subtitle: 'NEBULA · 12 SERVERS',
    kind: .success,
  );

  testWidgets('shows the title and the subtitle', (tester) async {
    await pumpCard(tester, detailed);

    expect(find.text('Subscription updated'), findsOneWidget);
    expect(find.text('NEBULA · 12 SERVERS'), findsOneWidget);
  });

  testWidgets('without a subtitle there is only the title line', (
    tester,
  ) async {
    await pumpCard(tester, plain);

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('a long subtitle stays on one line', (tester) async {
    await pumpCard(
      tester,
      const ToastMessage(
        id: 3,
        title: 'Invalid key or link',
        subtitle:
            'EXPECTED HTTPS:// · VLESS:// · SS:// · TROJAN:// · VMESS:// · HY2://',
        kind: .error,
      ),
    );

    final subtitle = tester.widget<Text>(find.textContaining('EXPECTED'));
    expect(subtitle.maxLines, 1);
    expect(subtitle.overflow, TextOverflow.ellipsis);
  });

  testWidgets('a tap calls onTap', (tester) async {
    var taps = 0;
    await pumpCard(tester, plain, onTap: () => taps++);

    await tester.tap(find.byType(ToastCard));

    expect(taps, 1);
  });

  testWidgets('the icon circle takes the color of the toast kind', (
    tester,
  ) async {
    for (final (mode, palette) in [
      (AppThemeMode.light, AppPalette.light),
      (AppThemeMode.dark, AppPalette.dark),
      (AppThemeMode.phosphor, AppPalette.phosphor),
    ]) {
      for (final (kind, color) in [
        (ToastKind.success, palette.ok),
        (ToastKind.error, palette.danger),
        (ToastKind.info, palette.accentIcon),
      ]) {
        await pumpCard(
          tester,
          ToastMessage(id: 1, title: 'T', kind: kind),
          mode: mode,
        );
        final circle = tester.widget<DecoratedBox>(
          find.byKey(const Key('toast-icon')),
        );
        expect(
          (circle.decoration as BoxDecoration).color,
          color,
          reason: '$mode $kind',
        );
      }
    }
  });

  testWidgets('the timer bar shrinks to nothing over the toast duration', (
    tester,
  ) async {
    await pumpCard(tester, plain);

    double width() => tester
        .widget<FractionallySizedBox>(find.byKey(const Key('toast-timer')))
        .widthFactor!;

    expect(width(), 1);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(width(), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(width(), 0);
  });

  testWidgets('a toast with a subtitle has a longer timer bar', (
    tester,
  ) async {
    await pumpCard(tester, detailed);

    double width() => tester
        .widget<FractionallySizedBox>(find.byKey(const Key('toast-timer')))
        .widthFactor!;

    await tester.pump(const Duration(milliseconds: 1600));
    expect(width(), closeTo(0.5, 0.01));
  });
}
