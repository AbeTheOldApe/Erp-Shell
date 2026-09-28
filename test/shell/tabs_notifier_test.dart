import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/shell/tabs/tabs_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late TabsNotifier tabs;

  TabsState state() => container.read(tabsProvider);
  List<String> keys() => [for (final t in state().tabs) t.tabKey];

  TabOpenResult open(
    String key, {
    int limit = 15,
    Map<String, String> query = const {},
    bool pinned = false,
  }) => tabs.open(
    moduleKey: key,
    title: key.toUpperCase(),
    limit: limit,
    query: query,
    pinned: pinned,
  );

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
    );
    tabs = container.read(tabsProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('starts empty', () {
    expect(state().tabs, isEmpty);
    expect(state().activeKey, isNull);
  });

  test('open adds and activates a tab', () {
    expect(open('siparis'), TabOpenResult.opened);
    expect(open('stok'), TabOpenResult.opened);
    expect(keys(), ['siparis', 'stok']);
    expect(state().activeKey, 'stok');
  });

  test('opening the same module twice does not create a second tab', () {
    open('siparis');
    open('stok');
    expect(open('siparis'), TabOpenResult.activated);
    expect(keys(), ['siparis', 'stok']);
    expect(state().activeKey, 'siparis');
  });

  test('re-opening with a new query updates the query version', () {
    open('siparis', query: {'id': '1'});
    open('siparis', query: {'id': '2'});
    final tab = state().byKey('siparis')!;
    expect(tab.query, {'id': '2'});
    expect(tab.queryVersion, 1);

    open('siparis');
    expect(state().byKey('siparis')!.query, {'id': '2'});
  });

  test('limit is enforced without closing anything', () {
    open('a', limit: 2);
    open('b', limit: 2);
    expect(open('c', limit: 2), TabOpenResult.limitReached);
    expect(keys(), ['a', 'b']);
    expect(state().activeKey, 'b');
    // An already open module can still be activated.
    expect(open('a', limit: 2), TabOpenResult.activated);
  });

  test('closing the active tab activates its neighbour', () {
    open('a');
    open('b');
    open('c');
    tabs.activate('b');
    tabs.close('b');
    expect(keys(), ['a', 'c']);
    expect(state().activeKey, 'c');
    tabs.close('c');
    expect(state().activeKey, 'a');
    tabs.close('a');
    expect(state().activeKey, isNull);
  });

  test('closing an inactive tab keeps the active one', () {
    open('a');
    open('b');
    tabs.close('a');
    expect(state().activeKey, 'b');
  });

  test('closeOthers, closeRight, closeAll', () {
    for (final key in ['a', 'b', 'c', 'd']) {
      open(key);
    }
    tabs.closeRight('b');
    expect(keys(), ['a', 'b']);
    expect(state().activeKey, 'b');

    open('c');
    tabs.closeOthers('a');
    expect(keys(), ['a']);
    expect(state().activeKey, 'a');

    open('b');
    tabs.closeAll();
    expect(keys(), isEmpty);
    expect(state().activeKey, isNull);
  });

  test('pinned tabs stay left and survive close operations', () {
    open('a');
    open('home', pinned: true);
    open('b');
    expect(keys(), ['home', 'a', 'b']);

    expect(tabs.close('home'), isFalse);
    tabs.closeOthers('b');
    expect(keys(), ['home', 'b']);
    tabs.closeAll();
    expect(keys(), ['home']);
    expect(state().activeKey, 'home');
  });

  test('reorder respects pinned tabs', () {
    open('home', pinned: true);
    open('a');
    open('b');
    open('c');
    tabs.reorder(3, 1); // c before a
    expect(keys(), ['home', 'c', 'a', 'b']);
    tabs.reorder(2, 0); // cannot pass the pinned tab
    expect(keys(), ['home', 'a', 'c', 'b']);
    tabs.reorder(0, 3); // pinned tab does not move
    expect(keys(), ['home', 'a', 'c', 'b']);
  });

  test('activate(null) shows no tab; neighbours wrap', () {
    open('a');
    open('b');
    open('c');
    tabs.activate(null);
    expect(state().activeKey, isNull);
    expect(tabs.neighbourKey(1), 'a');

    tabs.activate('c');
    expect(tabs.neighbourKey(1), 'a');
    expect(tabs.neighbourKey(-1), 'b');
  });

  test('setDirty and refresh', () {
    open('a');
    tabs.setDirty('a', true);
    expect(state().hasDirtyTabs, isTrue);
    tabs.refresh('a');
    final tab = state().byKey('a')!;
    expect(tab.isDirty, isFalse);
    expect(tab.generation, 1);
  });

  test('new tabs are not pinned by default', () {
    open('a');
    expect(state().byKey('a')!.pinned, isFalse);
  });
}
