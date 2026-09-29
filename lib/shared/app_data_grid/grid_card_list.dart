import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_grid_column.dart';

/// Phone layout of the grid: one card per row with the columns marked
/// [AppGridColumn.showInCard]. Values can be selected and copied.
class GridCardList<T> extends StatelessWidget {
  const GridCardList({
    required this.columns,
    required this.items,
    this.onOpen,
    super.key,
  });

  final List<AppGridColumn<T>> columns;
  final List<T> items;
  final ValueChanged<T>? onOpen;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final titleColumn = columns.firstWhere(
      (c) => c.cardTitle,
      orElse: () => columns.first,
    );
    final detailColumns = [
      for (final c in columns)
        if (c.showInCard && c != titleColumn) c,
    ];

    return SelectionArea(
      child: _list(spacing, theme, titleColumn, detailColumns),
    );
  }

  Widget _list(
    AppSpacing spacing,
    ThemeData theme,
    AppGridColumn<T> titleColumn,
    List<AppGridColumn<T>> detailColumns,
  ) {
    return ListView.separated(
      padding: EdgeInsets.all(spacing.sm),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen == null ? null : () => onOpen!(item),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    titleColumn.display(item),
                    style: theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: spacing.xs),
                  for (final column in detailColumns)
                    Padding(
                      padding: EdgeInsets.only(top: spacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              column.title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              column.display(item),
                              textAlign: column.alignEnd
                                  ? TextAlign.end
                                  : TextAlign.start,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
