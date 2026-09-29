import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/icons/icon_registry.dart';
import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/breakpoints.dart';
import '../core/utils/turkish_fold.dart';
import '../data/menu/menu_models.dart';
import '../data/menu/menu_tree.dart';
import 'personalization/favorites_controller.dart';
import 'personalization/recent_modules_controller.dart';
import 'shell_controller.dart';
import 'side_menu/menu_providers.dart';
import 'tabs/tabs_notifier.dart';

/// Opens the command palette (`Ctrl+K`, or the search icon): search the
/// modules of the menu and open one. Full screen on phones.
Future<void> showCommandPalette(
  BuildContext context,
  ShellController controller,
) {
  final compact = Breakpoints.of(context) == WindowSizeClass.compact;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final palette = CommandPalette(controller: controller);
      if (compact) return Dialog.fullscreen(child: palette);
      return Dialog(
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.only(
          top: context.spacing.xl * 2,
          left: context.spacing.md,
          right: context.spacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
          child: palette,
        ),
      );
    },
  );
}

class _Entry {
  const _Entry(this.leaf, this.path, {this.section});

  final MenuNode leaf;
  final List<String> path;

  /// Section header shown above this entry (empty query only).
  final String? section;
}

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({required this.controller, super.key});

  final ShellController controller;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _query = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_Entry> _entries() {
    final l10n = context.l10n;
    final all = MenuTree.leavesWithPath(ref.watch(menuNodesProvider));
    final query = _query.text.trim();
    if (query.isNotEmpty) {
      return [
        for (final item in all)
          if (turkishContains(item.leaf.title, query) ||
              turkishContains(item.path.join(' '), query))
            _Entry(item.leaf, item.path),
      ];
    }
    ({MenuNode leaf, List<String> path})? find(String key) {
      for (final item in all) {
        if (item.leaf.moduleKey == key) return item;
      }
      return null;
    }

    List<_Entry> section(String title, List<String> keys) {
      final found = [for (final key in keys) ?find(key)];
      return [
        for (final (index, item) in found.indexed)
          _Entry(item.leaf, item.path, section: index == 0 ? title : null),
      ];
    }

    // The module on screen is not a useful suggestion.
    final activeKey = ref.watch(tabsProvider.select((s) => s.activeKey));
    return [
      ...section(l10n.recentModules, [
        for (final key in ref.watch(recentModulesProvider))
          if (key != activeKey) key,
      ]),
      ...section(l10n.favorites, ref.watch(favoriteKeysProvider)),
    ];
  }

  void _open(_Entry entry) {
    Navigator.of(context).pop();
    widget.controller.openModule(entry.leaf.moduleKey!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final entries = _entries();
    final selected = entries.isEmpty
        ? -1
        : _selected.clamp(0, entries.length - 1);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => setState(
          () => _selected = entries.isEmpty ? 0 : (selected + 1) % entries.length,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => setState(
          () => _selected = entries.isEmpty
              ? 0
              : (selected - 1 + entries.length) % entries.length,
        ),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                hintText: l10n.commandPaletteHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              onChanged: (_) => setState(() => _selected = 0),
              onSubmitted: (_) {
                if (selected >= 0) _open(entries[selected]);
              },
            ),
          ),
          if (entries.isEmpty && _query.text.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Text(l10n.menuSearchNoResult, textAlign: TextAlign.center),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: spacing.sm),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final tile = ListTile(
                    selected: index == selected,
                    leading: Icon(IconRegistry.resolve(entry.leaf.icon)),
                    title: Text(entry.leaf.title),
                    subtitle: entry.path.isEmpty
                        ? null
                        : Text(entry.path.join(' › ')),
                    onTap: () => _open(entry),
                  );
                  if (entry.section == null) return tile;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          spacing.md,
                          spacing.sm,
                          spacing.md,
                          spacing.xs,
                        ),
                        child: Text(
                          entry.section!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      tile,
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
