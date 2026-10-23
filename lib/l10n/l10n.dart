import 'package:finora/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:finora/l10n/generated/app_localizations.dart';

/// Languages Finora ships in. `null` in settings means "follow the device".
const finoraLanguages = <String, String>{
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
};

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
