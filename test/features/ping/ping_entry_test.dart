import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';

void main() {
  group('pingQualityOf', () {
    test('below 80 ms is good', () {
      expect(pingQualityOf(79.9), PingQuality.good);
      expect(pingQualityOf(12), PingQuality.good);
    });

    test('80 to 160 ms inclusive is medium', () {
      expect(pingQualityOf(80), PingQuality.medium);
      expect(pingQualityOf(160), PingQuality.medium);
    });

    test('above 160 ms is poor', () {
      expect(pingQualityOf(160.1), PingQuality.poor);
      expect(pingQualityOf(900), PingQuality.poor);
    });
  });
}
