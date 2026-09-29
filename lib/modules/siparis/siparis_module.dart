import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../shared/app_data_grid/app_data_grid.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../module_def.dart';
import 'siparis_detail_page.dart';
import 'siparis_list_page.dart';

/// Orders: list → detail inside the module (no new tab).
///
/// The open record is reflected in the URL (`/m/siparis?id=1234`,
/// `?id=yeni` for a new order), so links, reload and the browser back
/// button work. The list stays alive behind the detail page, keeping its
/// page, sort and filters.
class SiparisModule extends StatefulWidget {
  const SiparisModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  State<SiparisModule> createState() => _SiparisModuleState();
}

/// What the detail page shows: an existing order or a new one.
sealed class _Target {
  const _Target();

  static _Target? fromQuery(Map<String, String> query) {
    final id = query['id'];
    if (id == null) return null;
    if (id == _NewTarget.queryValue) return const _NewTarget();
    final parsed = int.tryParse(id);
    return parsed == null ? null : _ExistingTarget(parsed);
  }

  Map<String, String> toQuery();
}

class _NewTarget extends _Target {
  const _NewTarget();

  static const queryValue = 'yeni';

  @override
  Map<String, String> toQuery() => const {'id': queryValue};

  @override
  bool operator ==(Object other) => other is _NewTarget;

  @override
  int get hashCode => 0;
}

class _ExistingTarget extends _Target {
  const _ExistingTarget(this.id);

  final int id;

  @override
  Map<String, String> toQuery() => {'id': '$id'};

  @override
  bool operator ==(Object other) => other is _ExistingTarget && other.id == id;

  @override
  int get hashCode => id;
}

class _SiparisModuleState extends State<SiparisModule> {
  final _grid = AppDataGridController();
  late _Target? _target = _Target.fromQuery(widget.ctx.query);
  late final StreamSubscription<Map<String, String>> _queryChanges;
  bool _dirty = false;

  /// Bumped to rebuild the detail page from scratch.
  int _detailGeneration = 0;

  @override
  void initState() {
    super.initState();
    _queryChanges = widget.ctx.queryChanges.listen(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryChanges.cancel();
    super.dispose();
  }

  /// URL changed from outside (back/forward, link, openModule with query).
  Future<void> _onQueryChanged(Map<String, String> query) async {
    final target = _Target.fromQuery(query);
    if (target == _target) return;
    if (!await _confirmLeave()) {
      // Stay; put the URL back to the page on screen.
      widget.ctx.setQuery(_target?.toQuery() ?? const {});
      return;
    }
    _show(target, updateUrl: false);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final l10n = context.l10n;
    return showConfirmDialog(
      context: context,
      title: l10n.discardChangesTitle,
      message: l10n.discardChangesMessage(widget.ctx.title),
      confirmLabel: l10n.discardChangesConfirm,
    );
  }

  void _show(_Target? target, {bool updateUrl = true}) {
    final leavingDetail = _target != null && target == null;
    _setDirty(false);
    setState(() {
      _target = target;
      _detailGeneration++;
    });
    if (updateUrl) widget.ctx.setQuery(target?.toQuery() ?? const {});
    // Whichever way the user came back (breadcrumb, browser back), the
    // record may have been saved or deleted meanwhile.
    if (leavingDetail) unawaited(_grid.refresh());
  }

  void _setDirty(bool value) {
    if (_dirty == value) return;
    _dirty = value;
    widget.ctx.setDirty(value);
  }

  Future<void> _back() async {
    if (!await _confirmLeave()) return;
    _show(null);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    return IndexedStack(
      index: target == null ? 0 : 1,
      sizing: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: target != null,
          child: SiparisListPage(
            ctx: widget.ctx,
            gridController: _grid,
            onOpen: (id) => _show(_ExistingTarget(id)),
            onNew: () => _show(const _NewTarget()),
          ),
        ),
        if (target == null)
          const SizedBox.shrink()
        else
          SiparisDetailPage(
            key: ValueKey(_detailGeneration),
            ctx: widget.ctx,
            id: switch (target) {
              _ExistingTarget(:final id) => id,
              _NewTarget() => null,
            },
            onBack: _back,
            onDirtyChanged: _setDirty,
            onCreated: (id) {
              // Show the saved order; the list gets the new row later.
              unawaited(_grid.refresh());
              _show(_ExistingTarget(id));
            },
          ),
      ],
    );
  }
}
