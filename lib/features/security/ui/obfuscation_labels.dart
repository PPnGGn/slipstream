import 'package:slipstream/features/security/data/obfuscation_settings.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Subtitle of the Fragment row: what it does while off, the values xray gets
/// while on.
String fragmentSubtitle(AppLocalizations l10n, ObfuscationSettings settings) =>
    settings.fragmentEnabled
    ? l10n.fragmentOn(
        settings.fragment.packets,
        settings.fragment.length,
        settings.fragment.delay,
      )
    : l10n.fragmentOff;

/// Subtitle of the Noise row, like [fragmentSubtitle].
String noiseSubtitle(AppLocalizations l10n, ObfuscationSettings settings) =>
    settings.noiseEnabled
    ? l10n.noiseOn(settings.noise.size, settings.noise.delay)
    : l10n.noiseOff;

/// What is wrong with a range field, with the bound it broke.
String rangeErrorText(
  AppLocalizations l10n,
  RangeInputError error, {
  required int min,
  required int max,
}) => switch (error) {
  RangeInputError.empty => l10n.rangeErrEmpty,
  RangeInputError.malformed => l10n.rangeErrMalformed,
  RangeInputError.reversed => l10n.rangeErrReversed,
  RangeInputError.tooSmall => l10n.rangeErrTooSmall(min),
  RangeInputError.tooLarge => l10n.rangeErrTooLarge(max),
};

/// The `packets` field takes `tlshello` as well as a range, so a malformed
/// value gets its own sentence.
String fragmentPacketsErrorText(AppLocalizations l10n, RangeInputError error) =>
    error == RangeInputError.malformed
    ? l10n.fragmentPacketsErrMalformed
    : rangeErrorText(
        l10n,
        error,
        min: fragmentPacketsBounds.min,
        max: fragmentPacketsBounds.max,
      );
