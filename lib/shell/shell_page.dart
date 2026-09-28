import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_controller.dart';
import '../core/l10n/locale_controller.dart';
import '../core/router/app_router.dart';
import '../core/router/routes.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/breakpoints.dart';
import '../data/menu/menu_tree.dart';
import 'content_states.dart';
import 'session_expired_dialog.dart';
import 'shell_controller.dart';
import 'side_menu/menu_providers.dart';
import 'side_menu/side_menu_panel.dart';
import 'side_menu/side_menu_rail.dart';
import 'tabs/shell_tab_bar.dart';
import 'tabs/tab_host.dart';
import 'tabs/tabs_notifier.dart';
import 'top_bar.dart';

/// Responsive shell: top bar, side menu, tab bar and content.
///
/// | class    | menu                                   | tabs            |
/// |----------|----------------------------------------|-----------------|
/// | expanded | panel (280) ⇄ rail (72), persisted     | tab bar, drag   |
/// | medium   | rail; hamburger opens an overlay panel | tab bar         |
/// | compact  | drawer                                 | bottom sheet    |
///
/// Only the layout changes with the window size; the content area keeps its
/// state across layouts through a [GlobalKey].
class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({required this.location, required this.child, super.key});

  /// Current URL (`/` or `/m/:moduleKey?...`).
  final Uri location;

  /// Nested router page; unused because the shell renders tabs itself.
  final Widget child;

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _contentKey = GlobalKey(debugLabel: 'shell-content');
  late final ShellController _controller;
  bool _overlayOpen = false;
  bool _drawerSearchFocus = false;
  bool _sessionDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = ShellController(
      ref: ref,
      router: ref.read(routerProvider),
      tabLimit: () => Breakpoints.tabLimit(Breakpoints.of(context)),
      onTabLimitReached: _showTabLimitWarning,
    );
    _syncLater();
  }

  @override
  void didUpdateWidget(ShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) _syncLater();
  }

  void _syncLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.syncFromLocation(widget.location);
    });
  }

  void _showTabLimitWarning() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.tabLimitReached)));
  }

  Future<void> _showSessionExpired() async {
    if (_sessionDialogOpen) return;
    _sessionDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SessionExpiredDialog(),
    );
    _sessionDialogOpen = false;
  }

  void _onMenuPressed(WindowSizeClass sizeClass) {
    switch (sizeClass) {
      case WindowSizeClass.expanded:
        ref.read(menuCollapsedProvider.notifier).toggle();
      case WindowSizeClass.medium:
        setState(() => _overlayOpen = !_overlayOpen);
      case WindowSizeClass.compact:
        _openDrawer(focusSearch: false);
    }
  }

  void _openDrawer({required bool focusSearch}) {
    setState(() => _drawerSearchFocus = focusSearch);
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeOverlay() {
    if (_overlayOpen) setState(() => _overlayOpen = false);
  }

  void _onEscape() {
    if (_overlayOpen) {
      _closeOverlay();
    } else if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  /// What the content area shows when no tab is active.
  Widget _placeholder() {
    final key = Routes.moduleKeyOf(widget.location);
    if (key == null) return const EmptyContentView();
    if (!ref.watch(menuLoadedProvider)) return const LoadingView();
    return switch (_controller.availabilityOf(key)) {
      ModuleAvailability.notFound => ModuleNotFoundView(moduleKey: key),
      ModuleAvailability.noAccess => const NoAccessView(),
      ModuleAvailability.available => const EmptyContentView(),
    };
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyW, alt: true):
        _controller.closeActiveTab,
    const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
        _controller.activateNeighbour(-1),
    const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
        _controller.activateNeighbour(1),
    for (final (index, key) in const [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ].indexed)
      SingleActivator(key, alt: true): () => _controller.activateIndex(index),
    const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
  };

  @override
  Widget build(BuildContext context) {
    ref.listen(menuLoadedProvider, (_, loaded) {
      if (loaded) _controller.syncFromLocation(widget.location);
    });
    ref.listen(menuNodesProvider, (_, nodes) {
      ref
          .read(tabsProvider.notifier)
          .renameAll((key) => MenuTree.findLeaf(nodes, key)?.title);
    });
    ref.listen(sessionProvider.select((s) => s.status), (_, status) {
      if (status == SessionStatus.expired) _showSessionExpired();
    });

    final sizeClass = Breakpoints.of(context);
    final spacing = context.spacing;
    final compact = sizeClass == WindowSizeClass.compact;
    final overlayOpen = _overlayOpen && sizeClass == WindowSizeClass.medium;

    final content = Column(
      children: [
        if (!compact) ...[
          ShellTabBar(reorderable: sizeClass == WindowSizeClass.expanded),
          const Divider(),
        ],
        Expanded(
          child: TabHost(key: _contentKey, placeholder: _placeholder()),
        ),
      ],
    );

    final Widget body = switch (sizeClass) {
      WindowSizeClass.expanded => Row(
        children: [
          if (ref.watch(menuCollapsedProvider))
            SideMenuRail(
              onExpandRequested: ref
                  .read(menuCollapsedProvider.notifier)
                  .toggle,
            )
          else
            SizedBox(width: spacing.menuWidth, child: const SideMenuPanel()),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
      WindowSizeClass.medium => Stack(
        children: [
          Row(
            children: [
              SideMenuRail(
                onExpandRequested: () => setState(() => _overlayOpen = true),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
          if (overlayOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeOverlay,
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.scrim.withValues(alpha: 0.32),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: spacing.menuWidth,
              child: Material(
                elevation: 8,
                child: SideMenuPanel(
                  autofocusSearch: true,
                  onModuleSelected: _closeOverlay,
                ),
              ),
            ),
          ],
        ],
      ),
      WindowSizeClass.compact => content,
    };

    return ShellScope(
      controller: _controller,
      child: CallbackShortcuts(
        bindings: _shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            appBar: TopBar(
              compact: compact,
              onMenuPressed: () => _onMenuPressed(sizeClass),
              onSearchPressed: () => _openDrawer(focusSearch: true),
            ),
            drawer: compact
                ? Drawer(
                    child: SafeArea(
                      child: SideMenuPanel(
                        autofocusSearch: _drawerSearchFocus,
                        onModuleSelected: () =>
                            _scaffoldKey.currentState?.closeDrawer(),
                      ),
                    ),
                  )
                : null,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // The nested router navigator must stay mounted.
                Offstage(child: widget.child),
                Positioned.fill(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
