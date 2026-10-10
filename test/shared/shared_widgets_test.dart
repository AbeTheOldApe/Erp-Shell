import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/shared/app_data_grid/grid_query.dart';
import 'package:erp_shell/shared/breadcrumb/breadcrumb.dart';
import 'package:erp_shell/shared/dialogs/adaptive_dialog.dart';
import 'package:erp_shell/shared/dialogs/confirm_dialog.dart';
import 'package:erp_shell/shared/filter_bar/filter_bar.dart';
import 'package:erp_shell/shared/responsive_form/responsive_form.dart';
import 'package:erp_shell/shared/responsive_scaffold/responsive_scaffold.dart';
import 'package:erp_shell/shared/states/empty_state.dart';
import 'package:erp_shell/shared/states/error_state.dart';
import 'package:erp_shell/shared/states/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_harness.dart';

/// Minimal app around [child] with theme and Turkish localizations.
Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('tr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(_app(child));
  await tester.pumpAndSettle();
}

void main() {
  group('ResponsiveForm', () {
    Widget form({GlobalKey<ResponsiveFormState>? key}) => ResponsiveForm(
      key: key,
      fields: [
        for (var i = 0; i < 3; i++)
          FormFieldSlot(
            TextFormField(
              key: ValueKey('f$i'),
              validator: (v) => i == 1 && (v ?? '').isEmpty ? 'gerekli' : null,
            ),
          ),
        FormFieldSlot.full(TextFormField(key: const ValueKey('full'))),
      ],
    );

    Future<double> fieldWidth(WidgetTester tester, Size size) async {
      await _pump(tester, form(), size);
      return tester.getSize(find.byKey(const ValueKey('f0'))).width;
    }

    testWidgets('3 / 2 / 1 columns by window class', (tester) async {
      final expanded = await fieldWidth(tester, const Size(1400, 900));
      final medium = await fieldWidth(tester, const Size(800, 900));
      final compact = await fieldWidth(tester, const Size(400, 900));
      // Each field takes a third, half or all of the (gap-reduced) width.
      expect(expanded, closeTo((1400 - 2 * 16) / 3, 1));
      expect(medium, closeTo((800 - 16) / 2, 1));
      expect(compact, closeTo(400, 1));
    });

    testWidgets('full-width slot spans the row', (tester) async {
      await _pump(tester, form(), const Size(1400, 900));
      expect(tester.getSize(find.byKey(const ValueKey('full'))).width, 1400);
    });

    testWidgets('validate focuses the first invalid field', (tester) async {
      final key = GlobalKey<ResponsiveFormState>();
      await _pump(tester, form(key: key), const Size(1400, 900));
      expect(key.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('gerekli'), findsOneWidget);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('f1')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });
  });

  group('Breadcrumb', () {
    final items = [
      const BreadcrumbItem('Satış Yönetimi Ana Sayfası'),
      const BreadcrumbItem('Siparişler ve Teklifler'),
      const BreadcrumbItem('Müşteri Grupları'),
      const BreadcrumbItem('SP-1234'),
    ];

    testWidgets('shows every item when it fits', (tester) async {
      // The test font draws every glyph as wide as the font size.
      await _pump(tester, Breadcrumb(items: items), const Size(2400, 900));
      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('folds the middle items when narrow; last stays', (
      tester,
    ) async {
      await _pump(tester, Breadcrumb(items: items), const Size(400, 900));
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(find.text('SP-1234'), findsOneWidget);
      expect(find.text('Müşteri Grupları'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Müşteri Grupları'), findsOneWidget);
    });

    testWidgets('two long items on a phone shrink instead of overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        Breadcrumb(
          items: const [
            BreadcrumbItem('Siparişler ve Teklifler'),
            BreadcrumbItem('SP-1234 Uzun Açıklama'),
          ],
        ),
        const Size(300, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('SP-1234 Uzun Açıklama'), findsOneWidget);
    });

    testWidgets('two short items that fit are not shortened', (tester) async {
      await _pump(
        tester,
        Breadcrumb(
          items: const [BreadcrumbItem('Siparişler'), BreadcrumbItem('SP-1')],
        ),
        const Size(800, 800),
      );
      final ancestor = find.text('Siparişler');
      final painter = TextPainter(
        text: TextSpan(
          text: 'Siparişler',
          style: tester.widget<Text>(ancestor).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(tester.getSize(ancestor).width, closeTo(painter.width, 1));
    });
  });

  group('ResponsiveScaffold', () {
    Widget scaffold() => ResponsiveScaffold(
      title: const Text('Başlık'),
      actions: [
        PageAction(
          icon: Icons.add,
          label: 'Yeni',
          onPressed: () {},
          primary: true,
        ),
        PageAction(icon: Icons.download, label: 'Dışa aktar', onPressed: () {}),
      ],
      body: const SizedBox(),
    );

    testWidgets('labelled buttons on wide screens', (tester) async {
      await _pump(tester, scaffold(), const Size(1400, 900));
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('Dışa aktar'), findsOneWidget);
    });

    testWidgets('phone: primary as icon, the rest in overflow', (tester) async {
      await _pump(tester, scaffold(), const Size(400, 900));
      expect(find.text('Dışa aktar'), findsNothing);
      expect(find.byTooltip('Yeni'), findsOneWidget);
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      expect(find.text('Dışa aktar'), findsOneWidget);
    });
  });

  group('dialogs', () {
    Future<void> openAdaptive(WidgetTester tester, Size size) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdaptiveAppDialog<void>(
              context: context,
              title: 'Kalem',
              content: (_) =>
                  const ResponsiveForm(fields: [FormFieldSlot(TextField())]),
              actions: (_) => [
                const TextButton(onPressed: null, child: Text('Kaydet')),
              ],
            ),
            child: const Text('aç'),
          ),
        ),
        size,
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('adaptive dialog is full screen on phones', (tester) async {
      await openAdaptive(tester, const Size(400, 800));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Kalem'), findsOneWidget);
    });

    testWidgets('adaptive dialog is centered elsewhere (no intrinsic '
        'layout error with ResponsiveForm)', (tester) async {
      await openAdaptive(tester, const Size(1400, 900));
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Kalem'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirm dialog returns the choice', (tester) async {
      bool? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(
              context: context,
              title: 'Sil',
              message: 'Emin misiniz?',
              confirmLabel: 'Sil',
              destructive: true,
            ),
            child: const Text('aç'),
          ),
        ),
        const Size(1400, 900),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('states', () {
    testWidgets('EmptyState, ErrorState with retry, SkeletonLoader', (
      tester,
    ) async {
      var retried = false;
      await _pump(
        tester,
        Column(
          children: [
            const Expanded(
              child: EmptyState(icon: Icons.inbox, title: 'Boş', message: 'x'),
            ),
            Expanded(child: ErrorState(onRetry: () => retried = true)),
          ],
        ),
        const Size(1400, 900),
      );
      expect(find.text('Boş'), findsOneWidget);
      expect(find.text('Veriler yüklenemedi.'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      expect(retried, isTrue);

      await tester.pumpWidget(_app(const SkeletonLoader(rows: 3)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
    });
  });

  group('FilterBar', () {
    const fields = [
      TextFilterField('musteri', 'Müşteri'),
      SelectFilterField('durum', 'Durum', options: {'Acik': 'Açık'}),
    ];

    testWidgets('row of fields on wide screens; text applies as you type', (
      tester,
    ) async {
      List<GridFilter>? filters;
      await _pump(
        tester,
        FilterBar(fields: fields, onChanged: (f) => filters = f),
        const Size(1400, 900),
      );
      await tester.enterText(find.byType(TextField), 'ahmet');
      await tester.pump(const Duration(milliseconds: 500));
      expect(filters, [
        const GridFilter('musteri', FilterOp.contains, 'ahmet'),
      ]);
      expect(find.text('Temizle'), findsOneWidget);
    });

    testWidgets('phone: button opens a sheet; Uygula applies', (tester) async {
      List<GridFilter>? filters;
      await _pump(
        tester,
        FilterBar(fields: fields, onChanged: (f) => filters = f),
        const Size(400, 800),
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Filtre'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ege');
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();
      expect(filters, [const GridFilter('musteri', FilterOp.contains, 'ege')]);
      expect(find.text('Filtre (1)'), findsOneWidget);
    });
  });
}
