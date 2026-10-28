import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/ui/favorite_toasts.dart';

void main() {
  group('favoriteToast', () {
    test('an added server is named in caps', () {
      expect(
        favoriteToast(added: true, serverName: 'Germany (BS-6)'),
        const ToastSpec(
          'Added to favorites',
          subtitle: 'GERMANY (BS-6)',
        ),
      );
    });

    test('a removed one is neutral, not a success', () {
      expect(
        favoriteToast(added: false, serverName: 'Auto'),
        const ToastSpec(
          'Removed from favorites',
          subtitle: 'AUTO',
          kind: ToastKind.info,
        ),
      );
    });
  });
}
