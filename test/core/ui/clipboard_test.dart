import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/ui/clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ToastCubit toasts;
  String? clipboard;

  setUp(() async {
    await GetIt.I.reset();
    toasts = ToastCubit();
    GetIt.I.registerSingleton<ToastCubit>(toasts);

    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await toasts.close();
    await GetIt.I.reset();
  });

  test('puts the text on the clipboard', () async {
    await copyToClipboard('vless://abc', title: 'Link copied');

    expect(clipboard, 'vless://abc');
  });

  test('confirms with a success toast carrying the subtitle', () async {
    await copyToClipboard(
      'vless://abc',
      title: 'Link copied',
      subtitle: 'SUBSCRIPTION URL · READY TO PASTE',
    );

    final toast = toasts.state!;
    expect(toast.title, 'Link copied');
    expect(toast.subtitle, 'SUBSCRIPTION URL · READY TO PASTE');
    expect(toast.kind, ToastKind.success);
  });

  test('the subtitle is optional', () async {
    await copyToClipboard('x', title: 'Copied');

    expect(toasts.state!.subtitle, isNull);
  });
}
