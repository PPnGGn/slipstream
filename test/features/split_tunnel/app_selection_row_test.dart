import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/widgets/wave_switch.dart';
import 'package:slipstream/features/split_tunnel/ui/widgets/app_selection_row.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRow(
    WidgetTester tester, {
    required bool selected,
    required ValueChanged<bool> onChanged,
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
          body: AppSelectionRow(
            app: app('com.chrome', label: 'Chrome'),
            selected: selected,
            onChanged: onChanged,
            loadIcon: (_) async => null,
          ),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  testWidgets('shows the name and the package', (tester) async {
    await pumpRow(tester, selected: false, onChanged: (_) {});
    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('com.chrome'), findsOneWidget);
  });

  testWidgets('the switch mirrors the selection', (tester) async {
    await pumpRow(tester, selected: true, onChanged: (_) {});
    expect(tester.widget<WaveSwitch>(find.byType(WaveSwitch)).value, isTrue);
  });

  testWidgets('tapping the row picks an unpicked app', (tester) async {
    bool? picked;
    await pumpRow(tester, selected: false, onChanged: (v) => picked = v);
    await tester.tap(find.text('Chrome'));
    expect(picked, isTrue);
  });

  testWidgets('tapping the row unpicks a picked app', (tester) async {
    bool? picked;
    await pumpRow(tester, selected: true, onChanged: (v) => picked = v);
    await tester.tap(find.text('Chrome'));
    expect(picked, isFalse);
  });

  testWidgets('tapping the switch reports once', (tester) async {
    final calls = <bool>[];
    await pumpRow(tester, selected: false, onChanged: calls.add);
    await tester.tap(find.byType(WaveSwitch));
    expect(calls, [true]);
  });
}
