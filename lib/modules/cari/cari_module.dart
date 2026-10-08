import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../shared/app_data_grid/app_data_grid.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../module_def.dart';
import 'cari_detail_page.dart';
import 'cari_list_page.dart';

/// Cari: list → detail inside the module (no new tab).
///
/// The open record is reflected in the URL (`/m/cari?id=123`, `?id=yeni` for
/// a new one), so links, reload and the browser back button work. The list
/// stays alive behind the detail page, keeping its page and filters.
class CariModule extends StatefulWidget {
  const CariModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  State<CariModule> createState() => _CariModuleState();
}

/// What the detail page shows: an existing Cari or a new one.
sealed class _Target {
  const _Target();

  static const newValue = 'yeni';

  static _Target? fromQuery(Map<String, String> query) {
    final id = query['id'];
    if (id == null) return null;
    if (id == newValue) return const _NewTarget();
    final parsed = int.tryParse(id);
    return parsed == null ? null : _ExistingTarget(parsed);
  }

  Map<String, String> toQuery();
}

class _NewTarget extends _Target {
  const _NewTarget();

  @override
  Map<String, String> toQuery() => const {'id': _Target.newValue};

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

class _CariModuleState extends State<CariModule> {
  final _grid = AppDataGridController();
  late _Target? _target = _Target.fromQuery(widget.ctx.query);
  late final StreamSubscription<Map<String, String>> _queryChanges;
  bool _dirty = false;
  bool _listStale = false;

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
    // Whichever way the user came back, the record may have changed.
    if (leavingDetail || _listStale) {
      _listStale = false;
      unawaited(_grid.refresh());
    }
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
          child: CariListPage(
            ctx: widget.ctx,
            gridController: _grid,
            onOpen: (id) => _show(_ExistingTarget(id)),
            onNew: () => _show(const _NewTarget()),
          ),
        ),
        if (target == null)
          const SizedBox.shrink()
        else
          CariDetailPage(
            key: ValueKey(_detailGeneration),
            ctx: widget.ctx,
            id: switch (target) {
              _ExistingTarget(:final id) => id,
              _NewTarget() => null,
            },
            onBack: _back,
            onDirtyChanged: _setDirty,
            onListStale: () => _listStale = true,
            onCreated: (id) {
              // Show the saved Cari; the list gets the new row now.
              unawaited(_grid.refresh());
              _show(_ExistingTarget(id));
            },
          ),
      ],
    );
  }
}
