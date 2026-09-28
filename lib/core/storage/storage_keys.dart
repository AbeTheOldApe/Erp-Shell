/// Storage keys (see `docs/menu-schema.md` §4).
abstract final class StorageKeys {
  static const menuCollapsed = 'ui.menu.collapsed';
  static String menuExpanded(int userId) => 'ui.menu.expanded.$userId';
  static const theme = 'ui.theme';
  static const locale = 'ui.locale';
  static const authTokens = 'auth.tokens';
}
