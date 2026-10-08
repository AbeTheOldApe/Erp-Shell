import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/utils/formatters.dart';
import '../app_data_grid/grid_query.dart';

/// A filter of a [FilterBar].
@immutable
sealed class FilterFieldDef {
  const FilterFieldDef(this.field, this.label);

  final String field;
  final String label;
}

/// Free text; matched with `contains` (Turkish-insensitive on the server).
class TextFilterField extends FilterFieldDef {
  const TextFilterField(super.field, super.label);
}

/// One value from a list; matched with `eq`.
class SelectFilterField extends FilterFieldDef {
  const SelectFilterField(super.field, super.label, {required this.options});

  /// value → label
  final Map<String, String> options;
}

/// Date range; sent as `gte` / `lte` with `yyyy-MM-dd` values.
class DateRangeFilterField extends FilterFieldDef {
  const DateRangeFilterField(super.field, super.label);
}

/// A checkbox; when ticked it is sent as `eq` `true`, otherwise not at all.
class BoolFilterField extends FilterFieldDef {
  const BoolFilterField(super.field, super.label);
}

/// Filters above a grid. Medium/expanded: a row of fields that apply as you
/// type. Compact: a "Filtre (n)" button that opens a bottom sheet with an
/// "Uygula" button.
class FilterBar extends StatefulWidget {
  const FilterBar({
    required this.fields,
    required this.onChanged,
    this.initial = const [],
    this.debounce = const Duration(milliseconds: 400),
    super.key,
  });

  final List<FilterFieldDef> fields;

  /// Delay before typing in a text field applies the filter.
  final Duration debounce;
  final ValueChanged<List<GridFilter>> onChanged;
  final List<GridFilter> initial;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late _FilterValues _values = _FilterValues.fromFilters(widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _update(_FilterValues values, {bool debounce = false}) {
    setState(() => _values = values);
    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(
        widget.debounce,
        () => widget.onChanged(_values.toFilters(widget.fields)),
      );
    } else {
      widget.onChanged(values.toFilters(widget.fields));
    }
  }

  Future<void> _openSheet() async {
    final result = await showModalBottomSheet<_FilterValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _FilterSheet(fields: widget.fields, initial: _values),
    );
    if (result != null) _update(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final active = _values.toFilters(widget.fields).length;

    if (Breakpoints.of(context) == WindowSizeClass.compact) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _openSheet,
            icon: const Icon(Icons.filter_list),
            label: Text(
              active == 0 ? l10n.filter : l10n.filterWithCount(active),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      child: Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final field in widget.fields)
            ..._FilterInputs.build(
              context,
              field,
              _values,
              (values, {debounce = false}) =>
                  _update(values, debounce: debounce),
              width: 200,
            ),
          if (active > 0)
            TextButton.icon(
              onPressed: () => _update(const _FilterValues()),
              icon: const Icon(Icons.clear),
              label: Text(l10n.filterClear),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.fields, required this.initial});

  final List<FilterFieldDef> fields;
  final _FilterValues initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterValues _values = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          0,
          spacing.md,
          spacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.filter, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: spacing.md),
              for (final field in widget.fields)
                for (final input in _FilterInputs.build(
                  context,
                  field,
                  _values,
                  (values, {debounce = false}) =>
                      setState(() => _values = values),
                ))
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.sm),
                    child: input,
                  ),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _FilterValues()),
                    child: Text(l10n.filterClear),
                  ),
                  SizedBox(width: spacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_values),
                    child: Text(l10n.filterApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _OnValues = void Function(_FilterValues values, {bool debounce});

/// Builds the input widgets of one filter field.
abstract final class _FilterInputs {
  static List<Widget> build(
    BuildContext context,
    FilterFieldDef def,
    _FilterValues values,
    _OnValues onChanged, {
    double? width,
  }) {
    final l10n = context.l10n;
    Widget sized(Widget child) =>
        width == null ? child : SizedBox(width: width, child: child);

    switch (def) {
      case TextFilterField():
        return [
          sized(
            _TextFilterInput(
              key: ValueKey('filter-${def.field}'),
              label: def.label,
              value: values.text[def.field] ?? '',
              onChanged: (text) => onChanged(
                values.copyWith(text: {...values.text, def.field: text}),
                debounce: true,
              ),
            ),
          ),
        ];
      case SelectFilterField():
        return [
          sized(
            DropdownButtonFormField<String?>(
              key: ValueKey('filter-${def.field}-${values.select[def.field]}'),
              initialValue: values.select[def.field],
              isExpanded: true,
              decoration: InputDecoration(labelText: def.label, isDense: true),
              items: [
                DropdownMenuItem<String?>(child: Text(l10n.filterAll)),
                for (final option in def.options.entries)
                  DropdownMenuItem(
                    value: option.key,
                    child: Text(option.value),
                  ),
              ],
              onChanged: (value) => onChanged(
                values.copyWith(select: {...values.select, def.field: value}),
              ),
            ),
          ),
        ];
      case BoolFilterField():
        return [
          sized(
            CheckboxListTile(
              key: ValueKey('filter-${def.field}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(def.label),
              value: values.flags[def.field] ?? false,
              onChanged: (checked) => onChanged(
                values.copyWith(
                  flags: {...values.flags, def.field: checked ?? false},
                ),
              ),
            ),
          ),
        ];
      case DateRangeFilterField():
        final range = values.dates[def.field] ?? const (null, null);
        return [
          sized(
            _DateInput(
              label: l10n.filterDateFrom(def.label),
              value: range.$1,
              onChanged: (date) => onChanged(
                values.copyWith(
                  dates: {...values.dates, def.field: (date, range.$2)},
                ),
              ),
            ),
          ),
          sized(
            _DateInput(
              label: l10n.filterDateTo(def.label),
              value: range.$2,
              onChanged: (date) => onChanged(
                values.copyWith(
                  dates: {...values.dates, def.field: (range.$1, date)},
                ),
              ),
            ),
          ),
        ];
    }
  }
}

class _TextFilterInput extends StatefulWidget {
  const _TextFilterInput({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFilterInput> createState() => _TextFilterInputState();
}

class _TextFilterInputState extends State<_TextFilterInput> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(
      labelText: widget.label,
      isDense: true,
      prefixIcon: const Icon(Icons.search),
    ),
    onChanged: widget.onChanged,
  );
}

/// Read-only field that opens a date picker; shows `dd.MM.yyyy`.
class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: l10n.filterClear,
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        isEmpty: value == null,
        child: Text(value == null ? '' : Formatters.date(value!)),
      ),
    );
  }
}

/// Current filter inputs, independent of their API form.
@immutable
class _FilterValues {
  const _FilterValues({
    this.text = const {},
    this.select = const {},
    this.dates = const {},
    this.flags = const {},
  });

  /// Rebuilds input values from filters (e.g. restored ones).
  factory _FilterValues.fromFilters(List<GridFilter> filters) {
    final text = <String, String>{};
    final select = <String, String?>{};
    final dates = <String, (DateTime?, DateTime?)>{};
    final flags = <String, bool>{};
    for (final f in filters) {
      switch (f.op) {
        case FilterOp.contains:
          text[f.field] = '${f.value ?? ''}';
        case FilterOp.eq when f.value is bool:
          flags[f.field] = f.value! as bool;
        case FilterOp.eq:
          select[f.field] = f.value as String?;
        case FilterOp.gte:
          final range = dates[f.field] ?? const (null, null);
          dates[f.field] = (DateTime.tryParse('${f.value}'), range.$2);
        case FilterOp.lte:
          final range = dates[f.field] ?? const (null, null);
          dates[f.field] = (range.$1, DateTime.tryParse('${f.value}'));
      }
    }
    return _FilterValues(
      text: text,
      select: select,
      dates: dates,
      flags: flags,
    );
  }

  final Map<String, String> text;
  final Map<String, String?> select;
  final Map<String, (DateTime?, DateTime?)> dates;
  final Map<String, bool> flags;

  _FilterValues copyWith({
    Map<String, String>? text,
    Map<String, String?>? select,
    Map<String, (DateTime?, DateTime?)>? dates,
    Map<String, bool>? flags,
  }) => _FilterValues(
    text: text ?? this.text,
    select: select ?? this.select,
    dates: dates ?? this.dates,
    flags: flags ?? this.flags,
  );

  List<GridFilter> toFilters(List<FilterFieldDef> fields) {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return [
      for (final def in fields)
        ...switch (def) {
          TextFilterField() => [
            if ((text[def.field] ?? '').trim().isNotEmpty)
              GridFilter(def.field, FilterOp.contains, text[def.field]!.trim()),
          ],
          SelectFilterField() => [
            if (select[def.field] != null)
              GridFilter(def.field, FilterOp.eq, select[def.field]),
          ],
          BoolFilterField() => [
            if (flags[def.field] ?? false)
              GridFilter(def.field, FilterOp.eq, true),
          ],
          DateRangeFilterField() => [
            if (dates[def.field]?.$1 case final from?)
              GridFilter(def.field, FilterOp.gte, iso(from)),
            if (dates[def.field]?.$2 case final to?)
              GridFilter(def.field, FilterOp.lte, iso(to)),
          ],
        },
    ];
  }
}
