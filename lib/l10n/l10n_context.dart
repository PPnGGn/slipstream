import 'package:flutter/widgets.dart';
import 'package:slipstream/l10n/gen/app_localizations.dart';

export 'package:slipstream/l10n/gen/app_localizations.dart';

/// `context.l10n.someKey` instead of `AppLocalizations.of(context)`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
