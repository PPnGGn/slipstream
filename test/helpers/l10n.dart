import 'dart:ui';

import 'package:slipstream/l10n/gen/app_localizations.dart';

/// The English texts, for tests of the pure text functions: they pin the
/// wording the app always had. `l10nRu` proves a function really reads the
/// translation instead of a literal.
final l10nEn = lookupAppLocalizations(const Locale('en'));
final l10nRu = lookupAppLocalizations(const Locale('ru'));

/// For a `MaterialApp` in a widget test, so `context.l10n` works (English,
/// the first of the supported languages).
const localizationsDelegates = AppLocalizations.localizationsDelegates;
const supportedLocales = AppLocalizations.supportedLocales;
