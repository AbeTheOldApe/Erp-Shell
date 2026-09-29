import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// "26–50 / 312" with previous / next page buttons.
class GridPager extends StatelessWidget {
  const GridPager({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    super.key,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final last = (page * pageSize).clamp(0, total);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            l10n.gridRange(
              Formatters.integer(first),
              Formatters.integer(last),
              Formatters.integer(total),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            tooltip: l10n.gridPreviousPage,
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 1 ? () => onPage(page - 1) : null,
          ),
          IconButton(
            tooltip: l10n.gridNextPage,
            icon: const Icon(Icons.chevron_right),
            onPressed: page < pageCount ? () => onPage(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
