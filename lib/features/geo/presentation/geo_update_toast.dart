import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';

/// The toast for the result of the manual "Обновить" on the Routing page.
/// Nothing newer is information, not a success: nothing changed.
ToastSpec geoUpdateToast(GeoUpdateOutcome outcome) => switch (outcome) {
  GeoUpdateOutcome.updated => const ToastSpec(
    'Geo bases updated',
    subtitle: 'GEOIP · GEOSITE',
  ),
  GeoUpdateOutcome.upToDate => const ToastSpec(
    'Geo bases are up to date',
    kind: ToastKind.info,
  ),
  GeoUpdateOutcome.failed => const ToastSpec(
    "Couldn't update geo bases",
    subtitle: 'CHECK CONNECTION · TRY AGAIN',
    kind: ToastKind.error,
  ),
};
