import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The toast for the result of the manual "Update" on the Routing page.
/// Nothing newer is information, not a success: nothing changed.
ToastSpec geoUpdateToast(AppLocalizations l10n, GeoUpdateOutcome outcome) =>
    switch (outcome) {
      GeoUpdateOutcome.updated => ToastSpec(
        l10n.geoToastUpdatedTitle,
        subtitle: l10n.geoToastUpdatedHint,
      ),
      GeoUpdateOutcome.upToDate => ToastSpec(
        l10n.geoToastUpToDate,
        kind: ToastKind.info,
      ),
      GeoUpdateOutcome.failed => ToastSpec(
        l10n.geoToastFailed,
        subtitle: l10n.failCheckConnectionHint,
        kind: ToastKind.error,
      ),
    };
