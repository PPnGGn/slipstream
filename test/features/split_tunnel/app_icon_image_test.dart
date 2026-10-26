import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/features/split_tunnel/ui/widgets/app_icon_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  Future<void> pumpIcon(
    WidgetTester tester, {
    required String label,
    required Future<Uint8List?> Function(String) loadIcon,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: cubit));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconImage(
            packageName: 'com.example',
            label: label,
            loadIcon: loadIcon,
          ),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  testWidgets('shows the first letter while the icon loads', (tester) async {
    await pumpIcon(tester, label: 'chrome', loadIcon: (_) async => png);
    expect(find.text('C'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the icon once it arrives', (tester) async {
    await pumpIcon(tester, label: 'Chrome', loadIcon: (_) async => png);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('C'), findsNothing);
  });

  testWidgets('keeps the letter when the app has no icon', (tester) async {
    await pumpIcon(tester, label: 'Chrome', loadIcon: (_) async => null);
    await tester.pump();
    expect(find.text('C'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an empty label shows a question mark', (tester) async {
    await pumpIcon(tester, label: '', loadIcon: (_) async => null);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('a rebuild does not ask for the icon again', (tester) async {
    var calls = 0;
    await pumpIcon(
      tester,
      label: 'Chrome',
      loadIcon: (_) async {
        calls++;
        return png;
      },
    );
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
  });
}
