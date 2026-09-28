import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import '../storage/storage_keys.dart';
import 'generated/app_localizations.dart';

/// App language, persisted in `localStorage`. Defaults to Turkish.
class LocaleController extends Notifier<Locale> {
  static const Locale fallback = Locale('tr');

  @override
  Locale build() {
    final stored = ref.read(localStoreProvider).read(StorageKeys.locale);
    return AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == stored,
      orElse: () => fallback,
    );
  }

  void set(Locale locale) {
    state = locale;
    ref.read(localStoreProvider).write(StorageKeys.locale, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
