import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/utils/file_download.dart';
import '../states/empty_state.dart';
import '../states/error_state.dart';
import '../states/skeleton_loader.dart';
import 'app_grid_column.dart';
import 'csv_export.dart';
import 'grid_card_list.dart';
import 'grid_pager.dart';
import 'grid_preferences.dart';
import 'grid_query.dart';
import 'grid_table.dart';

export 'app_grid_column.dart';
export 'grid_query.dart';
export 'local_grid_data_source.dart';

/// Lets the page refresh the grid or export it.
class AppDataGridController {
  _AppDataGridState<dynamic>? _state;

  /// Reloads the current page (e.g. after a record was saved).
  Future<void> refresh() => _state?._load() ?? Future.value();

  /// Downloads every row matching the current filters and sort as CSV.
  /// Returns false when nothing could be exported.
  Future<bool> exportCsv(String fileName) =>
      _state?._exportCsv(fileName) ?? Future.value(false);
}

/// Data grid of the app. Modules use this, never TrinaGrid directly.
///
/// - medium/expanded: table (TrinaGrid). Server-side paging and sorting
///   (click a header), `Ctrl+C` copies the selected cells tab separated,
///   column order/width/visibility are remembered per user.
/// - compact: card list; columns with [AppGridColumn.showInCard].
///
/// Rows are opened with a double click or Enter (table) or a tap (cards).
class AppDataGrid<T> extends ConsumerStatefulWidget {
  const AppDataGrid({
    required this.gridId,
    required this.moduleKey,
    required this.columns,
    required this.source,
    this.onOpen,
    this.filters = const [],
    this.initialSort = const [],
    this.pageSize = 25,
    this.controller,
    this.emptyTitle,
    this.emptyMessage,
    super.key,
  });

  /// Identifies the grid within its module (for column preferences).
  final String gridId;
  final String moduleKey;
  final List<AppGridColumn<T>> columns;
  final GridDataSource<T> source;
  final ValueChanged<T>? onOpen;

  /// Current filters, usually from a `FilterBar`. Changing them reloads
  /// from page 1.
  final List<GridFilter> filters;
  final List<GridSort> initialSort;
  final int pageSize;
  final AppDataGridController? controller;
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  ConsumerState<AppDataGrid<T>> createState() => _AppDataGridState<T>();
}

class _AppDataGridState<T> extends ConsumerState<AppDataGrid<T>> {
  late GridQuery _query = GridQuery(
    pageSize: widget.pageSize,
    sort: widget.initialSort,
    filters: widget.filters,
  );
  GridPage<T>? _page;
  Object? _error;
  bool _loading = false;
  int _request = 0;
  late GridPreferences _prefs;

  String get _prefsKey => GridPreferences.storageKey(
    ref.read(currentUserIdProvider),
    widget.moduleKey,
    widget.gridId,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _prefs = GridPreferences.load(ref.read(localStoreProvider), _prefsKey);
    _load();
  }

  @override
  void didUpdateWidget(AppDataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (!listEquals(oldWidget.filters, widget.filters)) {
      _query = _query.copyWith(page: 1, filters: widget.filters);
      _load();
    } else if (oldWidget.source != widget.source) {
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.source.fetch(_query);
      if (!mounted || request != _request) return;
      // A filter change can leave the current page past the end.
      final lastPage = (page.total / _query.pageSize).ceil().clamp(1, 1 << 30);
      if (_query.page > lastPage) {
        _query = _query.copyWith(page: lastPage);
        unawaited(_load());
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted && request == _request) setState(() => _loading = false);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _setSort(List<GridSort> sort) {
    _query = _query.copyWith(page: 1, sort: sort);
    _load();
  }

  void _setPage(int page) {
    _query = _query.copyWith(page: page);
    _load();
  }

  void _savePrefs(GridPreferences prefs) {
    if (prefs == _prefs) return;
    _prefs = prefs;
    prefs.save(ref.read(localStoreProvider), _prefsKey);
  }

  Future<bool> _exportCsv(String fileName) async {
    // Everything that matches the filters, in the current order.
    final all = await widget.source.fetch(
      _query.copyWith(page: 1, pageSize: 100000),
    );
    final visible = [
      for (final field in _prefs.applyOrder([
        for (final c in widget.columns) c.field,
      ]))
        if (!_prefs.hidden.contains(field))
          widget.columns.firstWhere((c) => c.field == field),
    ];
    return downloadTextFile(fileName, buildCsv(visible, all.items));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = Breakpoints.of(context) == WindowSizeClass.compact;
    final page = _page;

    if (page == null) {
      if (_error != null) return ErrorState(onRetry: _load);
      return const SkeletonLoader();
    }

    final Widget content;
    if (_error != null) {
      content = ErrorState(onRetry: _load);
    } else if (page.items.isEmpty) {
      content = EmptyState(
        icon: Icons.inbox_outlined,
        title: widget.emptyTitle ?? l10n.gridEmptyTitle,
        message: widget.emptyMessage,
      );
    } else if (compact) {
      content = GridCardList<T>(
        columns: widget.columns,
        items: page.items,
        onOpen: widget.onOpen,
      );
    } else {
      content = GridTable<T>(
        columns: widget.columns,
        items: page.items,
        sort: _query.sort,
        preferences: _prefs,
        onSort: _setSort,
        onOpen: widget.onOpen,
        onPreferencesChanged: _savePrefs,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 4,
          child: _loading ? const LinearProgressIndicator() : null,
        ),
        if (compact && widget.columns.any((c) => c.sortable))
          _CompactSortBar<T>(
            columns: widget.columns,
            sort: _query.sort,
            onSort: _setSort,
          ),
        Expanded(child: content),
        GridPager(
          page: _query.page,
          pageSize: _query.pageSize,
          total: page.total,
          onPage: _setPage,
        ),
      ],
    );
  }
}

/// Phone: sorting via a menu instead of column headers.
class _CompactSortBar<T> extends StatelessWidget {
  const _CompactSortBar({
    required this.columns,
    required this.sort,
    required this.onSort,
  });

  final List<AppGridColumn<T>> columns;
  final List<GridSort> sort;
  final ValueChanged<List<GridSort>> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = sort.isEmpty ? null : sort.first;
    final label = current == null
        ? l10n.gridSort
        : '${columns.firstWhere((c) => c.field == current.field, orElse: () => columns.first).title} '
              '${current.descending ? '↓' : '↑'}';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<GridSort?>(
          tooltip: l10n.gridSort,
          onSelected: (value) => onSort(value == null ? const [] : [value]),
          itemBuilder: (context) => [
            PopupMenuItem<GridSort?>(value: null, child: Text(l10n.gridNoSort)),
            for (final column in columns.where((c) => c.sortable)) ...[
              PopupMenuItem(
                value: GridSort(column.field),
                child: Text('${column.title} ↑'),
              ),
              PopupMenuItem(
                value: GridSort(column.field, descending: true),
                child: Text('${column.title} ↓'),
              ),
            ],
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort),
                SizedBox(width: context.spacing.xs),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
