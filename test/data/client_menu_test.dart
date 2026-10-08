import 'package:erp_shell/core/auth/permissions.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations_tr.dart';
import 'package:erp_shell/data/menu/client_menu.dart';
import 'package:erp_shell/data/menu/menu_models.dart';
import 'package:erp_shell/modules/registry.dart';
import 'package:erp_shell/shell/shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

List<MenuNode> _menu(ApiGrants grants) => buildClientMenu(
  entries: clientMenu,
  grants: grants,
  registry: moduleRegistry,
  l10n: AppLocalizationsTr(),
);

ApiGrants _grants({
  List<String> pages = const [],
  Map<String, List<String>> buttons = const {},
}) => ApiGrants.fromJson({'Pages': pages, 'Buttons': buttons});

void main() {
  group('menu filtering', () {
    test('no grants: no leaves and no empty group', () {
      expect(_menu(ApiGrants.none), isEmpty);
    });

    test('a page the user has makes its group and leaf visible', () {
      final menu = _menu(_grants(pages: ['CariMain']));
      expect(menu, hasLength(1));
      expect(menu.single.title, 'Tanımlar');
      expect(menu.single.isLeaf, isFalse);
      final leaf = menu.single.children.single;
      expect(leaf.title, 'Cariler');
      expect(leaf.moduleKey, 'cari');
      expect(leaf.icon, 'contacts');
      expect(leaf.badge, isNull);
    });

    test('an unknown page code or buttons alone show nothing', () {
      expect(_menu(_grants(pages: ['SiparisMain'])), isEmpty);
      expect(
        _menu(
          _grants(
            buttons: {
              'CariMain': ['KAYDET', 'SIL'],
            },
          ),
        ),
        isEmpty,
      );
    });

    test('mock-only modules never appear', () {
      final menu = _menu(_grants(pages: ['CariMain', 'siparis', 'musteri']));
      final keys = [
        for (final entry in menu) ...entry.children.map((c) => c.moduleKey),
      ];
      expect(keys, ['cari']);
    });

    test('the Cockpit needs no grant', () {
      expect(
        moduleAvailability(
          'cockpit',
          registry: moduleRegistry,
          menu: _menu(ApiGrants.none),
        ),
        ModuleAvailability.available,
      );
      expect(
        moduleAvailability(
          'cari',
          registry: moduleRegistry,
          menu: _menu(ApiGrants.none),
        ),
        ModuleAvailability.noAccess,
      );
    });

    test('every menu leaf matches the page code of its module', () {
      void check(List<ClientMenuEntry> entries) {
        for (final entry in entries) {
          switch (entry) {
            case ClientMenuGroup():
              check(entry.children);
            case ClientMenuLeaf():
              expect(
                moduleRegistry[entry.moduleKey]?.api?.pageCode,
                entry.pageCode,
                reason: entry.moduleKey,
              );
          }
        }
      }

      check(clientMenu);
    });
  });

  group('permission mapping', () {
    ModulePermissions cari(ApiGrants grants) =>
        moduleRegistry['cari']!.api!.resolve(grants);

    test('page and both buttons', () {
      final p = cari(
        _grants(
          pages: ['CariMain'],
          buttons: {
            'CariMain': ['KAYDET', 'SIL'],
          },
        ),
      );
      expect(p.canView, isTrue);
      expect(p.canAdd, isTrue);
      expect(p.canEdit, isTrue);
      expect(p.canDelete, isTrue);
    });

    test('KAYDET only: delete is false', () {
      final p = cari(
        _grants(
          pages: ['CariMain'],
          buttons: {
            'CariMain': ['KAYDET'],
          },
        ),
      );
      expect((p.canAdd, p.canEdit, p.canDelete), (true, true, false));
    });

    test('no button codes: only view', () {
      final p = cari(_grants(pages: ['CariMain']));
      expect(p.canView, isTrue);
      expect((p.canAdd, p.canEdit, p.canDelete), (false, false, false));
    });

    test('buttons of another page do not count', () {
      final p = cari(
        _grants(
          pages: ['CariMain'],
          buttons: {
            'OtherPage': ['KAYDET', 'SIL'],
          },
        ),
      );
      expect((p.canAdd, p.canEdit, p.canDelete), (false, false, false));
    });

    test('without the page nothing is granted, even with buttons', () {
      final p = cari(
        _grants(
          buttons: {
            'CariMain': ['KAYDET', 'SIL'],
          },
        ),
      );
      expect(p, ModulePermissions.none);
    });

    test('a flag without a button code stays false', () {
      const api = ModuleApiPermissions(pageCode: 'P', addButton: 'A');
      final p = api.resolve(
        _grants(
          pages: ['P'],
          buttons: {
            'P': ['A', 'B'],
          },
        ),
      );
      expect((p.canAdd, p.canEdit, p.canDelete), (true, false, false));
    });

    test('the menu leaf carries the computed permissions', () {
      final menu = _menu(
        _grants(
          pages: ['CariMain'],
          buttons: {
            'CariMain': ['KAYDET'],
          },
        ),
      );
      expect(
        menu.single.children.single.permissions,
        const ModulePermissions(canView: true, canAdd: true, canEdit: true),
      );
    });
  });
}
