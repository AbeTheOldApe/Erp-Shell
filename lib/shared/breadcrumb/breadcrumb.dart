import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';

@immutable
class BreadcrumbItem {
  const BreadcrumbItem(this.label, {this.onTap});

  final String label;

  /// Navigates to this level; `null` for the current (last) item.
  final VoidCallback? onTap;
}

/// "Siparişler › SP-1234". When the items do not fit, the middle items fold
/// into a "…" menu; if even that is too wide only "…" and the last item
/// remain. The last item is always shown (ellipsized if needed).
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({required this.items, super.key})
    : assert(items.length > 0);

  final List<BreadcrumbItem> items;

  static const _separator = ' › ';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleLarge!;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        double widthOf(String text) => (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 1,
        )..layout()).width;

        // Room for the "…" button and separators.
        const overflowWidth = 48.0;
        final separator = widthOf(_separator);
        final labels = [for (final item in items) widthOf(item.label)];
        final full =
            labels.fold<double>(0, (a, b) => a + b) +
            separator * (items.length - 1);

        final List<Widget> children;
        if (full <= constraints.maxWidth) {
          children = _crumbs(context, items, style, shrink: false);
        } else if (items.length <= 2) {
          children = _crumbs(context, items, style, shrink: true);
        } else {
          final middle = items.sublist(1, items.length - 1);
          final collapsed =
              labels.first + labels.last + overflowWidth + separator * 2;
          children = collapsed <= constraints.maxWidth
              ? [
                  ..._crumbs(context, [items.first], style),
                  _Separator(style),
                  _OverflowMenu(middle),
                  _Separator(style),
                  ..._crumbs(context, [items.last], style),
                ]
              : [
                  _OverflowMenu(items.sublist(0, items.length - 1)),
                  _Separator(style),
                  ..._crumbs(context, [items.last], style),
                ];
        }
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }

  /// With [shrink] the ancestors may be ellipsized too (only when the row
  /// would overflow otherwise); the last item can always shrink.
  List<Widget> _crumbs(
    BuildContext context,
    List<BreadcrumbItem> crumbs,
    TextStyle style, {
    bool shrink = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final item = crumbs[i];
      final isLast = identical(item, items.last);
      if (i > 0) widgets.add(_Separator(style));
      final text = Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isLast
            ? style
            : style.copyWith(color: scheme.primary),
      );
      if (isLast) {
        widgets.add(Flexible(flex: 2, child: text));
        continue;
      }
      final link = InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(context.spacing.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: text,
          ),
        ),
      );
      // When the row would overflow (e.g. large text scale on a phone),
      // ancestors shrink too; the current item keeps more of the room.
      widgets.add(shrink ? Flexible(child: link) : link);
    }
    return widgets;
  }
}

class _Separator extends StatelessWidget {
  const _Separator(this.style);

  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    Breadcrumb._separator,
    style: style.copyWith(color: Theme.of(context).colorScheme.outline),
  );
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu(this.hidden);

  final List<BreadcrumbItem> hidden;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: context.l10n.breadcrumbMore,
      icon: const Icon(Icons.more_horiz),
      onSelected: (index) => hidden[index].onTap?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < hidden.length; i++)
          PopupMenuItem(value: i, child: Text(hidden[i].label)),
      ],
    );
  }
}
