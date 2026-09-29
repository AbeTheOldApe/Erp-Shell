import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_controller.dart';
import '../core/l10n/generated/app_localizations.dart';
import '../core/l10n/locale_controller.dart';
import '../core/network/api_exception.dart';
import '../core/theme/theme_controller.dart';
import 'shell_controller.dart';
import 'shell_dialogs.dart';
import 'side_menu/menu_providers.dart';
import 'tabs/open_modules_sheet.dart';
import 'tabs/tabs_notifier.dart';

/// Top bar: hamburger, active module title, (phone) search and open
/// modules, notifications placeholder and the user menu.
class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({
    required this.compact,
    required this.onMenuPressed,
    this.onSearchPressed,
    super.key,
  });

  final bool compact;
  final VoidCallback onMenuPressed;
  final VoidCallback? onSearchPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = ref.watch(tabsProvider.select((s) => s.activeTab?.title));
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: l10n.menuToggle,
        icon: const Icon(Icons.menu),
        onPressed: onMenuPressed,
      ),
      title: Text(title ?? l10n.appTitle, overflow: TextOverflow.ellipsis),
      actions: [
        if (onSearchPressed != null)
          IconButton(
            tooltip: l10n.commandPaletteTooltip,
            icon: const Icon(Icons.search),
            onPressed: onSearchPressed,
          ),
        if (compact) const OpenModulesButton(),
        IconButton(
          tooltip: l10n.notifications,
          icon: const Icon(Icons.notifications_none),
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.notificationsEmpty))),
        ),
        const UserMenuButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}

enum _UserAction {
  themeLight,
  themeDark,
  themeSystem,
  refreshMenu,
  expireSession,
  shortcutsHelp,
  logout,
}

class _LocaleAction {
  const _LocaleAction(this.locale);

  final Locale locale;
}

/// Profile, theme, language, "Menüyü yenile", (mock) "Oturum süresini
/// doldur" and sign out.
class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final canSimulateExpiry = ref
        .read(sessionProvider.notifier)
        .canSimulateExpiry;
    final initials = user?.displayName.characters.firstOrNull ?? '?';

    return PopupMenuButton<Object>(
      tooltip: l10n.userMenu,
      onSelected: (value) => _onSelected(context, ref, value),
      icon: CircleAvatar(radius: 16, child: Text(initials)),
      itemBuilder: (context) => [
        PopupMenuItem<Object>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(user?.displayName ?? ''),
            subtitle: Text(user?.roles.join(', ') ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        _header(context, l10n.theme),
        CheckedPopupMenuItem<Object>(
          value: _UserAction.themeLight,
          checked: themeMode == ThemeMode.light,
          child: Text(l10n.themeLight),
        ),
        CheckedPopupMenuItem<Object>(
          value: _UserAction.themeDark,
          checked: themeMode == ThemeMode.dark,
          child: Text(l10n.themeDark),
        ),
        CheckedPopupMenuItem<Object>(
          value: _UserAction.themeSystem,
          checked: themeMode == ThemeMode.system,
          child: Text(l10n.themeSystem),
        ),
        const PopupMenuDivider(),
        _header(context, l10n.language),
        for (final supported in AppLocalizations.supportedLocales)
          CheckedPopupMenuItem<Object>(
            value: _LocaleAction(supported),
            checked: supported.languageCode == locale.languageCode,
            child: Text(lookupAppLocalizations(supported).languageName),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _UserAction.refreshMenu,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh),
            title: Text(l10n.refreshMenu),
          ),
        ),
        if (canSimulateExpiry)
          PopupMenuItem<Object>(
            value: _UserAction.expireSession,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_off_outlined),
              title: Text(l10n.expireSession),
            ),
          ),
        PopupMenuItem<Object>(
          value: _UserAction.shortcutsHelp,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.keyboard_outlined),
            title: Text(l10n.shortcutsHelp),
          ),
        ),
        PopupMenuItem<Object>(
          value: _UserAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<Object> _header(BuildContext context, String text) =>
      PopupMenuItem<Object>(
        enabled: false,
        height: 32,
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    Object value,
  ) async {
    final theme = ref.read(themeModeProvider.notifier);
    final shell = ShellScope.of(context);
    switch (value) {
      case _LocaleAction(:final locale):
        ref.read(localeProvider.notifier).set(locale);
      case _UserAction.themeLight:
        theme.set(ThemeMode.light);
      case _UserAction.themeDark:
        theme.set(ThemeMode.dark);
      case _UserAction.themeSystem:
        theme.set(ThemeMode.system);
      case _UserAction.refreshMenu:
        await refreshMenu(context, ref);
      case _UserAction.expireSession:
        ref.read(sessionProvider.notifier).simulateExpiry();
        // The next API call fails with 401 and the refresh fails too, which
        // opens the "sign in again" dialog.
        await refreshMenu(context, ref, quiet: true);
      case _UserAction.shortcutsHelp:
        await showShortcutsHelp(context);
      case _UserAction.logout:
        await shell.logout();
    }
  }
}

/// Reloads the menu and reports the result with a snackbar.
Future<void> refreshMenu(
  BuildContext context,
  WidgetRef ref, {
  bool quiet = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await ref.read(menuProvider.notifier).reload();
    if (!quiet) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.menuRefreshed)));
    }
  } on SessionExpiredException {
    // The session dialog takes over.
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.menuLoadError)));
  }
}
