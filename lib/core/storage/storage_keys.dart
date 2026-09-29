/// Storage keys (see `docs/menu-schema.md` §4).
abstract final class StorageKeys {
  static const menuCollapsed = 'ui.menu.collapsed';
  static String menuExpanded(int userId) => 'ui.menu.expanded.$userId';
  static const theme = 'ui.theme';
  static const locale = 'ui.locale';
  static const authTokens = 'auth.tokens';

  /// Open tabs and the active tab of this browser tab (`sessionStorage`).
  static String tabs(int userId) => 'ui.tabs.$userId';

  /// Recently used module keys, most recent first (`localStorage`).
  static String recentModules(int userId) => 'ui.recent.$userId';

  /// Written on sign-out; other browser tabs sign out when they see it
  /// change (`storage` event).
  static const logoutSignal = 'auth.logoutSignal';
}
