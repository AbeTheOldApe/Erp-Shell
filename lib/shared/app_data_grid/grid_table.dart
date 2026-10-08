import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trina_grid/trina_grid.dart';

import 'app_grid_column.dart';
import 'grid_preferences.dart';
import 'grid_query.dart';

/// Table layout of [AppDataGrid], rendered with TrinaGrid.
///
/// TrinaGrid only renders the current page: sorting is reported back
/// ([onSort]) instead of sorting locally, and new pages replace the rows.
/// Column moves, resizes and hide/show from the column menu are reported
/// through [onPreferencesChanged].
class GridTable<T> extends StatefulWidget {
  const GridTable({
    required this.columns,
    required this.items,
    required this.sort,
    required this.preferences,
    required this.onSort,
    required this.onPreferencesChanged,
    this.onOpen,
    super.key,
  });

  final List<AppGridColumn<T>> columns;
  final List<T> items;
  final List<GridSort> sort;
  final GridPreferences preferences;
  final ValueChanged<List<GridSort>> onSort;
  final ValueChanged<GridPreferences> onPreferencesChanged;
  final ValueChanged<T>? onOpen;

  @override
  State<GridTable<T>> createState() => _GridTableState<T>();
}

class _GridTableState<T> extends State<GridTable<T>> {
  TrinaGridStateManager? _grid;
  Timer? _saveTimer;
  late final List<TrinaColumn> _columns = _buildColumns();
  late final List<TrinaRow<T>> _initialRows = _buildRows(widget.items);

  @override
  void didUpdateWidget(GridTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final grid = _grid;
    if (grid != null && !identical(oldWidget.items, widget.items)) {
      grid.removeAllRows(notify: false);
      grid.appendRows(_buildRows(widget.items));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _grid?.removeListener(_onGridChanged);
    super.dispose();
  }

  List<TrinaColumn> _buildColumns() {
    final prefs = widget.preferences;
    final byField = {for (final c in widget.columns) c.field: c};
    final sort = widget.sort.isEmpty ? null : widget.sort.first;
    return [
      for (final field in prefs.applyOrder([...byField.keys]))
        _buildColumn(byField[field]!, prefs, sort),
    ];
  }

  static TrinaColumn _buildColumn(
    AppGridColumn<dynamic> column,
    GridPreferences prefs,
    GridSort? sort,
  ) {
    final align = column.alignEnd
        ? TrinaColumnTextAlign.end
        : TrinaColumnTextAlign.start;
    return TrinaColumn(
      title: column.title,
      field: column.field,
      type: TrinaColumnType.text(),
      readOnly: true,
      width: prefs.widths[column.field] ?? column.width,
      hide: prefs.hidden.contains(column.field),
      enableSorting: column.sortable,
      renderer: column.cell == null
          ? null
          : (rendererContext) => column.cell!(rendererContext.row.data),
      enableFilterMenuItem: false,
      enableEditingMode: false,
      textAlign: align,
      titleTextAlign: align,
      // Keep right-aligned titles clear of the column menu icon.
      titlePadding: column.alignEnd
          ? const EdgeInsets.only(left: 10, right: 36)
          : null,
      sort: switch (sort) {
        GridSort(:final field, :final descending) when field == column.field =>
          descending ? TrinaColumnSort.descending : TrinaColumnSort.ascending,
        _ => TrinaColumnSort.none,
      },
    );
  }

  List<TrinaRow<T>> _buildRows(List<T> items) => [
    for (final item in items)
      TrinaRow<T>(
        data: item,
        cells: {
          for (final column in widget.columns)
            column.field: TrinaCell(value: column.display(item)),
        },
      ),
  ];

  void _onLoaded(TrinaGridOnLoadedEvent event) {
    _grid = event.stateManager
      // Sorting is done by the server.
      ..setSortOnlyEvent(true)
      ..setSelectingMode(TrinaGridSelectingMode.cell)
      ..addListener(_onGridChanged);
  }

  void _onSorted(TrinaGridOnSortedEvent event) {
    final column = event.column;
    widget.onSort(
      column.sort.isNone
          ? const []
          : [GridSort(column.field, descending: column.sort.isDescending)],
    );
  }

  /// Column order, width and visibility, saved shortly after a change.
  void _onGridChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final grid = _grid;
      if (grid == null || !mounted) return;
      final columns = grid.refColumns.originalList;
      widget.onPreferencesChanged(
        GridPreferences(
          order: [for (final c in columns) c.field],
          widths: {for (final c in columns) c.field: c.width},
          hidden: {
            for (final c in columns)
              if (c.hide) c.field,
          },
        ),
      );
    });
  }

  void _openCurrent() {
    final row = _grid?.currentRow;
    final data = row?.data;
    if (data is T) widget.onOpen?.call(data);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _openCurrent,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _openCurrent,
      },
      child: TrinaGrid(
        columns: _columns,
        rows: _initialRows,
        mode: TrinaGridMode.readOnly,
        onLoaded: _onLoaded,
        onSorted: _onSorted,
        onRowDoubleTap: (event) {
          final data = event.row.data;
          if (data is T) widget.onOpen?.call(data);
        },
        configuration: _configuration(context),
      ),
    );
  }

  TrinaGridConfiguration _configuration(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final cellStyle = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurface,
    );
    final columnStyle = theme.textTheme.labelLarge!.copyWith(
      color: scheme.onSurface,
    );
    const rowHeight = 48.0;

    final style = dark
        ? TrinaGridStyleConfig.dark(
            gridBackgroundColor: scheme.surface,
            rowColor: scheme.surface,
            evenRowColor: scheme.surfaceContainerLow,
            activatedColor: scheme.secondaryContainer,
            activatedBorderColor: scheme.primary,
            inactivatedBorderColor: scheme.outlineVariant,
            gridBorderColor: scheme.outlineVariant,
            borderColor: scheme.outlineVariant,
            iconColor: scheme.onSurfaceVariant,
            disabledIconColor: scheme.outline,
            menuBackgroundColor: scheme.surfaceContainer,
            cellColorInReadOnlyState: scheme.surface,
            rowHoveredColor: scheme.surfaceContainerHighest,
            enableRowHoverColor: true,
            cellTextStyle: cellStyle,
            columnTextStyle: columnStyle,
            rowHeight: rowHeight,
            columnHeight: rowHeight,
          )
        : TrinaGridStyleConfig(
            gridBackgroundColor: scheme.surface,
            rowColor: scheme.surface,
            evenRowColor: scheme.surfaceContainerLow,
            activatedColor: scheme.secondaryContainer,
            activatedBorderColor: scheme.primary,
            inactivatedBorderColor: scheme.outlineVariant,
            gridBorderColor: scheme.outlineVariant,
            borderColor: scheme.outlineVariant,
            iconColor: scheme.onSurfaceVariant,
            disabledIconColor: scheme.outline,
            menuBackgroundColor: scheme.surfaceContainer,
            cellColorInReadOnlyState: scheme.surface,
            rowHoveredColor: scheme.surfaceContainerHighest,
            enableRowHoverColor: true,
            cellTextStyle: cellStyle,
            columnTextStyle: columnStyle,
            rowHeight: rowHeight,
            columnHeight: rowHeight,
          );

    final turkish = Localizations.localeOf(context).languageCode == 'tr';
    return TrinaGridConfiguration(
      style: style,
      localeText: turkish
          ? const TrinaGridLocaleText.turkish()
          : const TrinaGridLocaleText(),
      enableMoveDownAfterSelecting: false,
    );
  }
}
