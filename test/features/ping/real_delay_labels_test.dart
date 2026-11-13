import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';
import 'package:slipstream/features/ping/presentation/ui/real_delay_labels.dart';

import '../../helpers/l10n.dart';

void main() {
  group('realDelayResultText', () {
    test('nothing to show before the first check and while it runs', () {
      expect(
        realDelayResultText(l10nEn, const RealDelayEntry.notTested()),
        isNull,
      );
      expect(
        realDelayResultText(l10nEn, const RealDelayEntry.measuring()),
        isNull,
      );
    });

    test('a number in milliseconds', () {
      expect(
        realDelayResultText(l10nEn, const RealDelayEntry.measured(412)),
        '412 ms',
      );
    });

    test('a timeout and any other failure read differently', () {
      expect(
        realDelayResultText(
          l10nEn,
          const RealDelayEntry.failed(RealDelayFailure.timeout),
        ),
        'no answer',
      );
      expect(
        realDelayResultText(
          l10nEn,
          const RealDelayEntry.failed(RealDelayFailure.other),
        ),
        'failed',
      );
    });
  });

  group('realDelayButtonText', () {
    test('Check at first, Check again once there is a result', () {
      expect(
        realDelayButtonText(l10nEn, const RealDelayEntry.notTested()),
        'Check',
      );
      expect(
        realDelayButtonText(l10nEn, const RealDelayEntry.measured(100)),
        'Check again',
      );
      expect(
        realDelayButtonText(
          l10nEn,
          const RealDelayEntry.failed(RealDelayFailure.other),
        ),
        'Check again',
      );
    });

    test('says it is working while it works', () {
      expect(
        realDelayButtonText(l10nEn, const RealDelayEntry.measuring()),
        'Checking…',
      );
    });
  });
}
