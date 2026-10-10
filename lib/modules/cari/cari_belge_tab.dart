import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/utils/decimal_units.dart';
import '../../core/utils/formatters.dart';
import '../../shared/app_data_grid/grid_pager.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/states/empty_state.dart';
import '../../shared/states/error_state.dart';
import '../../shared/states/skeleton_loader.dart';
import '../module_def.dart';
import 'cari_belge_form.dart';
import 'cari_belge_messages.dart';
import 'data/cari_belge_models.dart';
import 'data/cari_belge_repository.dart';

/// Documents of one saved Cari: a server-paged list (table; cards on
/// phones). Tapping a row opens the document (read-only without edit
/// permission). "Yeni belge" needs add and delete needs delete permission;
/// buttons the user may not use are hidden. Unlike addresses, documents of a
/// Netsis-linked Cari are not read-only.
class CariBelgeTab extends ConsumerStatefulWidget {
  const CariBelgeTab({
    required this.cariId,
    required this.permissions,
    required this.onDirtyChanged,
    this.pageSize = 25,
    super.key,
  });

  final int cariId;

  /// The sub-permissions of the Belgeler tab.
  final ModulePermissions permissions;

  /// A document form is open with (or without) unsaved changes.
  final ValueChanged<bool> onDirtyChanged;
  final int pageSize;

  @override
  ConsumerState<CariBelgeTab> createState() => _CariBelgeTabState();
}

class _CariBelgeTabState extends ConsumerState<CariBelgeTab> {
  BelgeListe? _list;
  ApiFailure<BelgeListe>? _failure;
  Object? _error;
  bool _loading = true;
  int _page = 1;

  SessionController get _session => ref.read(sessionProvider.notifier);
  CariBelgeRepository get _repository => ref.read(cariBelgeRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int? page]) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _failure = null;
      _error = null;
    });
    try {
      final result = await _session.guard(
        () => _repository.list(
          widget.cariId,
          page: target,
          pageSize: widget.pageSize,
        ),
      );
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<BelgeListe>(:final data):
          // The last row of the last page was deleted: step back.
          if (data.items.isEmpty && data.total > 0 && target > 1) {
            return _load(target - 1);
          }
          setState(() {
            _loading = false;
            _page = target;
            _list = data;
          });
        case ApiFailure<BelgeListe>():
          setState(() {
            _loading = false;
            _failure = result;
          });
      }
    } on SessionExpiredException {
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  void _show(BelgeFailureView view) {
    final message = view.message;
    if (message == null) return;
    if (view.isInfo) {
      showInfo(context, message);
    } else {
      showErrorBanner(context, message);
    }
  }

  Future<void> _openForm([BelgeOzet? ozet]) async {
    final l10n = context.l10n;
    CariBelge? belge;
    if (ozet != null) {
      try {
        final result = await _session.guard(() => _repository.get(ozet.id));
        if (!mounted) return;
        switch (result) {
          case ApiSuccess<CariBelge>(:final data):
            belge = data;
          case ApiFailure<CariBelge>():
            final view = mapBelgeFailure(l10n, result);
            _show(view);
            if (view.refreshList) await _load();
            return;
        }
      } on SessionExpiredException {
        return;
      } catch (_) {
        if (mounted) showErrorBanner(context, l10n.errorLoadFailed);
        return;
      }
    }
    if (!mounted) return;
    final result = await showBelgeDialog(
      context,
      cariId: widget.cariId,
      belge: belge,
      readOnly: belge != null && !widget.permissions.canEdit,
      onDirtyChanged: widget.onDirtyChanged,
    );
    if (!mounted || result == null) return;
    if (result == BelgeDialogResult.saved) showSuccess(context, l10n.saved);
    await _load();
  }

  Future<void> _delete(BelgeOzet ozet) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmMessage(_title(ozet)),
      confirmLabel: l10n.actionDelete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;
    try {
      final result = await _session.guard(() => _repository.delete(ozet.id));
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<void>():
          showSuccess(context, l10n.deleted);
          await _load();
        case ApiFailure<void>():
          final view = mapBelgeFailure(l10n, result);
          _show(view);
          if (view.refreshList) await _load();
      }
    } on SessionExpiredException {
      // The session dialog takes over.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.deleteFailed);
    }
  }

  static String _title(BelgeOzet o) =>
      o.no.isEmpty ? o.tipi : '${o.tipi} ${o.no}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;

    if (_loading && _list == null) return const SkeletonLoader(rows: 4);
    final failure = _failure;
    if (failure != null) {
      if (failure.messageCode == 1004 && failure.isBusinessRule) {
        return EmptyState(icon: Icons.search_off, title: l10n.recordNotFound);
      }
      return ErrorState(
        message: mapBelgeFailure(l10n, failure).message,
        onRetry: _load,
      );
    }
    final list = _list;
    if (_error != null || list == null) return ErrorState(onRetry: _load);

    final compact = Breakpoints.of(context) == WindowSizeClass.compact;
    final canDelete = widget.permissions.canDelete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.permissions.canAdd)
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(l10n.belgeNew),
              ),
            ),
          ),
        Expanded(
          child: list.total == 0
              ? EmptyState(
                  icon: Icons.description_outlined,
                  title: l10n.belgeEmpty,
                )
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  children: [
                    if (!compact) const _HeaderRow(),
                    for (final ozet in list.items)
                      compact
                          ? _BelgeCard(
                              ozet: ozet,
                              onTap: () => _openForm(ozet),
                              onDelete: canDelete ? () => _delete(ozet) : null,
                            )
                          : _BelgeRow(
                              ozet: ozet,
                              onTap: () => _openForm(ozet),
                              onDelete: canDelete ? () => _delete(ozet) : null,
                            ),
                  ],
                ),
        ),
        if (list.total > 0)
          GridPager(
            page: _page,
            pageSize: widget.pageSize,
            total: list.total,
            onPage: _load,
          ),
      ],
    );
  }
}

String _total(BelgeOzet o) =>
    formatUnits(o.toplamKurus, decimals: CariBelgeLimits.tutarDecimals);

String _no(BelgeOzet o) => o.no.isEmpty ? '-' : o.no;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelLarge;
    Widget cell(String text, int flex, {TextAlign? align}) => Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: align),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      child: Row(
        children: [
          cell(l10n.belgeColTarih, 2),
          cell(l10n.belgeColTipi, 3),
          cell(l10n.belgeColNo, 2),
          cell(l10n.belgeColDoviz, 1),
          cell(l10n.belgeColKalem, 1, align: TextAlign.end),
          cell(l10n.belgeColToplam, 2, align: TextAlign.end),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BelgeRow extends StatelessWidget {
  const _BelgeRow({required this.ozet, required this.onTap, this.onDelete});

  final BelgeOzet ozet;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, int flex, {TextAlign? align}) => Expanded(
      flex: flex,
      child: Text(text, textAlign: align, overflow: TextOverflow.ellipsis),
    );
    return Card(
      margin: EdgeInsets.only(bottom: context.spacing.xs),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                cell(Formatters.date(ozet.tarih), 2),
                cell(ozet.tipi, 3),
                cell(_no(ozet), 2),
                cell(ozet.dovizKodu, 1),
                cell('${ozet.kalemSayisi}', 1, align: TextAlign.end),
                cell(_total(ozet), 2, align: TextAlign.end),
                SizedBox(
                  width: 48,
                  child: onDelete == null
                      ? null
                      : IconButton(
                          tooltip: context.l10n.actionDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: onDelete,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BelgeCard extends StatelessWidget {
  const _BelgeCard({required this.ozet, required this.onTap, this.onDelete});

  final BelgeOzet ozet;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.only(bottom: context.spacing.sm),
      child: ListTile(
        onTap: onTap,
        title: Text('${Formatters.date(ozet.tarih)} · ${ozet.tipi}'),
        subtitle: Text(
          '${l10n.belgeColNo}: ${_no(ozet)} · '
          '${l10n.belgeColKalem}: ${ozet.kalemSayisi}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_total(ozet)} ${ozet.dovizKodu}'),
            if (onDelete != null)
              IconButton(
                tooltip: l10n.actionDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
