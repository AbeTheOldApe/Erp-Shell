import 'package:flutter/widgets.dart';

import '../core/auth/permissions.dart';

export '../core/auth/permissions.dart' show ModulePermissions;

/// Registration of a module: `moduleKey -> builder`.
@immutable
class ModuleDef {
  const ModuleDef(this.key, this.builder, {this.load, this.home = false});

  final String key;
  final Widget Function(ModuleContext ctx) builder;

  /// Loads the module's code first (`deferred as` library `loadLibrary`).
  /// [builder] is called only after it completes.
  final Future<void> Function()? load;

  /// The home module (Cockpit): opened as the pinned first tab for every
  /// user, shown at `/`, and not listed in the menu. At most one module may
  /// set this.
  final bool home;
}

/// What the shell provides to a module. Modules never import each other;
/// they navigate with [openModule].
abstract class ModuleContext {
  String get moduleKey;

  /// Title from the menu data (modules do not hard-code their own title).
  String get title;

  /// Permissions of the current user on this module (from the menu).
  ModulePermissions get permissions;

  /// URL query parameters the module was opened with.
  Map<String, String> get query;

  /// Emits the new query when it changes from outside the module: the
  /// module is opened again with a query, or the browser goes back/forward.
  Stream<Map<String, String>> get queryChanges;

  /// Reflects the module's inner navigation in the URL (e.g. `{'id': '7'}`
  /// when a record is opened, `{}` back on the list). Adds a browser history
  /// entry; does not emit on [queryChanges].
  void setQuery(Map<String, String> query);

  /// Marks the tab as having unsaved changes.
  void setDirty(bool value);

  /// Opens (or switches to) another module.
  void openModule(String moduleKey, {Map<String, String>? query});

  /// Rebuilds this module from scratch.
  void requestRefresh();
}
