import 'package:flutter/foundation.dart';

import '../../core/auth/permissions.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../modules/module_def.dart';
import 'menu_models.dart';

/// An entry of the menu defined in the shell for the real API
/// (`docs/api-contract.md` §5.1).
@immutable
sealed class ClientMenuEntry {
  const ClientMenuEntry({
    required this.id,
    required this.title,
    required this.icon,
    this.sortOrder = 0,
  });

  final int id;

  /// Title from the ARB files.
  final String Function(AppLocalizations l10n) title;
  final String icon;
  final int sortOrder;
}

class ClientMenuGroup extends ClientMenuEntry {
  const ClientMenuGroup({
    required super.id,
    required super.title,
    required super.icon,
    super.sortOrder,
    required this.children,
  });

  final List<ClientMenuEntry> children;
}

class ClientMenuLeaf extends ClientMenuEntry {
  const ClientMenuLeaf({
    required super.id,
    required super.title,
    required super.icon,
    super.sortOrder,
    required this.moduleKey,
    required this.pageCode,
  });

  final String moduleKey;

  /// API page code; the leaf is visible only if `Yetkiler.Pages` has it.
  final String pageCode;
}

/// The menu of the real mode. Adding a module: one leaf here and the
/// `ModuleDef` in the registry.
final List<ClientMenuEntry> clientMenu = [
  ClientMenuGroup(
    id: 1,
    title: (l10n) => l10n.menuGroupDefinitions,
    icon: 'folder',
    sortOrder: 10,
    children: [
      ClientMenuLeaf(
        id: 11,
        title: (l10n) => l10n.menuLeafCari,
        icon: 'contacts',
        sortOrder: 10,
        moduleKey: 'cari',
        pageCode: 'CariMain',
      ),
    ],
  ),
];

/// Filters [entries] by [grants] into the shell's menu model. Leaves whose
/// page code is not granted (or whose module is not registered / has no API
/// mapping) are dropped, then groups without leaves. `badge` is always null.
List<MenuNode> buildClientMenu({
  required List<ClientMenuEntry> entries,
  required ApiGrants grants,
  required Map<String, ModuleDef> registry,
  required AppLocalizations l10n,
}) {
  final nodes = <MenuNode>[];
  for (final entry in entries) {
    switch (entry) {
      case ClientMenuLeaf():
        final api = registry[entry.moduleKey]?.api;
        if (api == null || !grants.hasPage(entry.pageCode)) continue;
        nodes.add(
          MenuNode(
            id: entry.id,
            title: entry.title(l10n),
            icon: entry.icon,
            moduleKey: entry.moduleKey,
            sortOrder: entry.sortOrder,
            permissions: api.resolve(grants),
          ),
        );
      case ClientMenuGroup():
        final children = buildClientMenu(
          entries: entry.children,
          grants: grants,
          registry: registry,
          l10n: l10n,
        );
        if (children.isEmpty) continue;
        nodes.add(
          MenuNode(
            id: entry.id,
            title: entry.title(l10n),
            icon: entry.icon,
            sortOrder: entry.sortOrder,
            children: children,
          ),
        );
    }
  }
  nodes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return nodes;
}
