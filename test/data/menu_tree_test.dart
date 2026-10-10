import 'dart:convert';
import 'dart:io';

import 'package:erp_shell/core/auth/permissions.dart';
import 'package:erp_shell/data/menu/menu_models.dart';
import 'package:erp_shell/data/menu/menu_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const _view = ModulePermissions(canView: true);

MenuNode _leaf(
  int id,
  String title,
  String key, {
  int order = 0,
  bool view = true,
}) => MenuNode(
  id: id,
  title: title,
  moduleKey: key,
  sortOrder: order,
  permissions: view ? _view : const ModulePermissions(),
);

MenuNode _group(
  int id,
  String title,
  List<MenuNode> children, {
  int order = 0,
}) => MenuNode(id: id, title: title, sortOrder: order, children: children);

List<String> _titles(List<MenuNode> nodes) => [
  for (final node in nodes) ...[node.title, ..._titles(node.children)],
];

List<MenuNode> _loadMock(String username) {
  final json = File('assets/mock/menu_$username.json').readAsStringSync();
  return MenuTree.normalize(
    parseMenuResponse(jsonDecode(json) as Map<String, dynamic>),
  );
}

void main() {
  group('normalize', () {
    test('sorts siblings by sortOrder', () {
      final menu = MenuTree.normalize([
        _group(2, 'B', [
          _leaf(21, 'b2', 'b2', order: 2),
          _leaf(22, 'b1', 'b1', order: 1),
        ], order: 20),
        _group(1, 'A', [_leaf(11, 'a', 'a')], order: 10),
      ]);
      expect(_titles(menu), ['A', 'a', 'B', 'b1', 'b2']);
    });

    test('hides groups without visible leaves, at any depth', () {
      final menu = MenuTree.normalize([
        _group(1, 'Empty', []),
        _group(2, 'Nested empty', [_group(21, 'Inner', [])]),
        _group(3, 'No view', [_leaf(31, 'x', 'x', view: false)]),
        _group(4, 'Visible', [_leaf(41, 'y', 'y')]),
      ]);
      expect(_titles(menu), ['Visible', 'y']);
    });

    test('drops nodes deeper than three levels', () {
      final menu = MenuTree.normalize([
        _group(1, 'L1', [
          _group(2, 'L2', [
            _leaf(3, 'L3 leaf', 'l3'),
            _group(4, 'L3 group', [_leaf(5, 'L4 leaf', 'l4')]),
          ]),
        ]),
      ]);
      expect(_titles(menu), ['L1', 'L2', 'L3 leaf']);
    });
  });

  group('filter', () {
    final menu = MenuTree.normalize([
      _group(1, 'Satış', [
        _leaf(11, 'Siparişler', 'siparis'),
        _leaf(12, 'Müşteriler', 'musteri'),
      ]),
      _group(2, 'Üretim', [_leaf(21, 'İş Emri', 'is-emri')]),
      _group(3, 'Raporlar', [
        _group(31, 'Depo Raporları', [_leaf(311, 'Stok Raporu', 'rapor-stok')]),
      ]),
    ]);

    test('empty query returns the tree unchanged', () {
      expect(MenuTree.filter(menu, '  '), same(menu));
    });

    test('matches with Turkish folding', () {
      expect(_titles(MenuTree.filter(menu, 'iş emri')), ['Üretim', 'İş Emri']);
      expect(_titles(MenuTree.filter(menu, 'IŞ EMRİ')), ['Üretim', 'İş Emri']);
      expect(_titles(MenuTree.filter(menu, 'siparis')), [
        'Satış',
        'Siparişler',
      ]);
    });

    test('keeps parents of deep matches', () {
      expect(_titles(MenuTree.filter(menu, 'stok')), [
        'Raporlar',
        'Depo Raporları',
        'Stok Raporu',
      ]);
    });

    test('a matching group keeps all its children', () {
      expect(_titles(MenuTree.filter(menu, 'satis')), [
        'Satış',
        'Siparişler',
        'Müşteriler',
      ]);
    });

    test('no match returns empty', () {
      expect(MenuTree.filter(menu, 'xyz'), isEmpty);
    });
  });

  group('lookups', () {
    final menu = _loadMock('yonetici');

    test('findLeaf and ancestorIds', () {
      expect(MenuTree.findLeaf(menu, 'rapor-stok')?.title, 'Stok Raporu');
      expect(MenuTree.findLeaf(menu, 'nope'), isNull);
      expect(MenuTree.ancestorIds(menu, 'rapor-stok'), [3, 32]);
      expect(MenuTree.ancestorIds(menu, 'siparis'), [1]);
    });

    test('groupIds and leaves', () {
      expect(MenuTree.groupIds(menu), {1, 2, 3, 32, 4, 5});
      expect(MenuTree.leaves(menu).map((l) => l.moduleKey), [
        'siparis',
        'musteri',
        'stok',
        'sevkiyat',
        'rapor-satis',
        'rapor-stok',
        'kullanici',
        'cari',
      ]);
    });
  });

  group('mock menus per user', () {
    List<String?> keysOf(String user) =>
        MenuTree.leaves(_loadMock(user)).map((l) => l.moduleKey).toList();

    test('every user has Tanımlar › Cariler (moduleKey cari)', () {
      for (final user in ['yonetici', 'satis', 'depo']) {
        final menu = _loadMock(user);
        expect(MenuTree.findLeaf(menu, 'cari')?.title, 'Cariler', reason: user);
        expect(MenuTree.ancestorIds(menu, 'cari'), [5], reason: user);
      }
    });

    test('yonetici sees everything', () {
      expect(keysOf('yonetici'), hasLength(8));
    });

    test('depo sees Depo, read-only Siparişler and Raporlar, badge on '
        'Sevkiyat', () {
      final menu = _loadMock('depo');
      expect(keysOf('depo'), [
        'siparis',
        'stok',
        'sevkiyat',
        'rapor-satis',
        'rapor-stok',
        'cari',
      ]);
      // Read-only Cariler: the buttons are hidden, also in mock mode.
      expect(
        MenuTree.findLeaf(menu, 'cari')!.permissions,
        const ModulePermissions(canView: true),
      );
      expect(
        MenuTree.findLeaf(menu, 'siparis')!.permissions,
        const ModulePermissions(canView: true),
      );
      expect(MenuTree.findLeaf(menu, 'sevkiyat')!.badge, '3');
      expect(
        MenuTree.findLeaf(menu, 'rapor-satis')!.permissions,
        const ModulePermissions(canView: true),
      );
      expect(menu.map((n) => n.title), isNot(contains('Ayarlar')));
    });

    test('satis sees Satış (without delete) and Tanımlar', () {
      final menu = _loadMock('satis');
      expect(keysOf('satis'), ['siparis', 'musteri', 'cari']);
      expect(menu.map((n) => n.title), ['Satış', 'Tanımlar']);
      expect(
        MenuTree.findLeaf(menu, 'cari')!.permissions,
        const ModulePermissions(
          canView: true,
          canAdd: true,
          canEdit: true,
          canDelete: true,
        ),
      );
      expect(
        MenuTree.findLeaf(menu, 'siparis')!.permissions!.canDelete,
        isFalse,
      );
    });
  });
}
