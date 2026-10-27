import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/presentation/geo_update_toast.dart';

void main() {
  test('updated bases are a success', () {
    expect(
      geoUpdateToast(GeoUpdateOutcome.updated),
      const ToastSpec(
        'Geo bases updated',
        subtitle: 'GEOIP · GEOSITE',
        kind: ToastKind.success,
      ),
    );
  });

  test('nothing newer is information, not a success', () {
    expect(
      geoUpdateToast(GeoUpdateOutcome.upToDate),
      const ToastSpec('Geo bases are up to date', kind: ToastKind.info),
    );
  });

  test('a failed check is an error with a hint', () {
    expect(
      geoUpdateToast(GeoUpdateOutcome.failed),
      const ToastSpec(
        "Couldn't update geo bases",
        subtitle: 'CHECK CONNECTION · TRY AGAIN',
        kind: ToastKind.error,
      ),
    );
  });
}
