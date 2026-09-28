import 'package:flutter/widgets.dart';

import '../core/auth/permissions.dart';

export '../core/auth/permissions.dart' show ModulePermissions;

/// Registration of a module: `moduleKey -> builder`.
@immutable
class ModuleDef {
  const ModuleDef(this.key, this.builder);

  final String key;
  final Widget Function(ModuleContext ctx) builder;
}

/// What the shell provides to a module. Modules never import each other;
/// they navigate with [openModule].
abstract class ModuleContext {
  String get moduleKey;

  /// Permissions of the current user on this module (from the menu).
  ModulePermissions get permissions;

  /// URL query parameters the module was opened with.
  Map<String, String> get query;

  /// Emits the new query when the module is opened again while its tab is
  /// already open.
  Stream<Map<String, String>> get queryChanges;

  /// Marks the tab as having unsaved changes.
  void setDirty(bool value);

  /// Opens (or switches to) another module.
  void openModule(String moduleKey, {Map<String, String>? query});

  /// Rebuilds this module from scratch.
  void requestRefresh();
}
