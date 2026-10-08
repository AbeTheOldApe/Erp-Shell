import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/shared/app_data_grid/grid_query.dart';
import 'package:erp_shell/shared/filter_bar/filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_harness.dart';

void main() {
  testWidgets('BoolFilterField sends eq true when ticked, nothing otherwise', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1200, 800));
    var filters = <GridFilter>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: true, apiBaseUrl: '/api'),
          ),
          localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: FilterBar(
              fields: const [
                TextFilterField('arama', 'Ara'),
                BoolFilterField('pasif', 'Pasifleri göster'),
              ],
              onChanged: (f) => filters = f,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pasifleri göster'));
    await tester.pump();
    expect(filters, [const GridFilter('pasif', FilterOp.eq, true)]);

    await tester.tap(find.text('Pasifleri göster'));
    await tester.pump();
    expect(filters, isEmpty);
  });

  testWidgets('the text filter waits for the configured debounce', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1200, 800));
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: FilterBar(
            debounce: const Duration(milliseconds: 300),
            fields: const [TextFilterField('arama', 'Ara')],
            onChanged: (_) => calls++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'bora');
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
  });
}
