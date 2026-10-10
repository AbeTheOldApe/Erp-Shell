import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../shell_controller.dart';
import 'tabs_notifier.dart';

/// Phone: top bar button with the number of open modules.
class OpenModulesButton extends ConsumerWidget {
  const OpenModulesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tabsProvider.select((s) => s.tabs.length));
    final controller = ShellScope.of(context);
    return IconButton(
      tooltip: context.l10n.openModules,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => OpenModulesSheet(controller: controller),
      ),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.layers_outlined),
      ),
    );
  }
}

/// Bottom sheet listing open modules: tap to switch, ✕ to close.
class OpenModulesSheet extends ConsumerWidget {
  const OpenModulesSheet({required this.controller, super.key});

  final ShellController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tabsProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              child: Text(l10n.openModules, style: theme.textTheme.titleMedium),
            ),
            if (state.tabs.isEmpty)
              Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Text(l10n.openModulesEmpty, textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tab in state.tabs)
                      ListTile(
                        selected: tab.tabKey == state.activeKey,
                        leading: tab.isDirty
                            ? Tooltip(
                                message: l10n.tabUnsavedChanges,
                                child: const Icon(Icons.circle, size: 10),
                              )
                            : null,
                        title: Text(tab.title),
                        onTap: () {
                          Navigator.of(context).pop();
                          controller.activateTab(tab.tabKey);
                        },
                        onLongPress: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => _TabActionsSheet(
                            controller: controller,
                            tabKey: tab.tabKey,
                          ),
                        ),
                        trailing: tab.pinned
                            ? null
                            : IconButton(
                                tooltip: l10n.tabClose,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    controller.closeTab(tab.tabKey),
                              ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Long-press actions for a tab on phones (touch equivalent of the tab
/// context menu).
class _TabActionsSheet extends StatelessWidget {
  const _TabActionsSheet({required this.controller, required this.tabKey});

  final ShellController controller;
  final String tabKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void run(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.tabRefresh),
            onTap: () => run(() => controller.refreshTab(tabKey)),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n.tabCloseOthers),
            onTap: () => run(() => controller.closeOthers(tabKey)),
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: Text(l10n.tabCloseAll),
            onTap: () => run(controller.closeAll),
          ),
        ],
      ),
    );
  }
}
