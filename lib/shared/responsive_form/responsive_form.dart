import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';

/// A field of a [ResponsiveForm]. [span] is the number of columns it takes
/// (capped by the column count of the current layout).
@immutable
class FormFieldSlot {
  const FormFieldSlot(this.child, {this.span = 1});

  /// Takes the full row in every layout.
  const FormFieldSlot.full(this.child) : span = 99;

  final Widget child;
  final int span;
}

/// Form laid out in 3 columns (expanded), 2 (medium) or 1 (compact).
/// Validation messages appear under each field. [validate] focuses and
/// reveals the first invalid field.
class ResponsiveForm extends StatefulWidget {
  const ResponsiveForm({
    required this.fields,
    this.onChanged,
    this.maxColumns = 3,
    super.key,
  });

  final List<FormFieldSlot> fields;

  /// Upper bound for the column count, e.g. 2 inside a dialog that is
  /// narrower than the window.
  final int maxColumns;

  /// Called whenever any field changes (e.g. to mark the page dirty).
  final VoidCallback? onChanged;

  static int columnsFor(WindowSizeClass sizeClass) => switch (sizeClass) {
    WindowSizeClass.expanded => 3,
    WindowSizeClass.medium => 2,
    WindowSizeClass.compact => 1,
  };

  @override
  State<ResponsiveForm> createState() => ResponsiveFormState();
}

class ResponsiveFormState extends State<ResponsiveForm> {
  final _formKey = GlobalKey<FormState>();

  /// Validates every field. On failure the first invalid field is scrolled
  /// into view and focused. Returns whether the form is valid.
  bool validate() {
    final form = _formKey.currentState;
    if (form == null || form.validate()) return true;
    final invalid = _firstInvalidField();
    if (invalid != null) {
      Scrollable.ensureVisible(
        invalid,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
      );
      _focusInside(invalid);
    }
    return false;
  }

  void reset() => _formKey.currentState?.reset();

  /// First [FormFieldState] with an error, in layout (tree) order.
  BuildContext? _firstInvalidField() {
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement &&
          element.state is FormFieldState &&
          (element.state as FormFieldState).hasError) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    (_formKey.currentContext as Element?)?.visitChildren(visit);
    return found;
  }

  /// Focuses the first focusable widget inside [field].
  void _focusInside(BuildContext field) {
    FocusNode? node;
    void visit(Element element) {
      if (node != null) return;
      final widget = element.widget;
      if (widget is EditableText) {
        node = widget.focusNode;
      } else if (widget is Focus && widget.focusNode != null) {
        node = widget.focusNode;
      }
      if (node == null) element.visitChildren(visit);
    }

    (field as Element).visitChildren(visit);
    (node ?? Focus.maybeOf(field))?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final columns = ResponsiveForm.columnsFor(
      Breakpoints.of(context),
    ).clamp(1, widget.maxColumns);
    return Form(
      key: _formKey,
      onChanged: widget.onChanged,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = spacing.md;
          final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final field in widget.fields)
                SizedBox(
                  width: _widthFor(field.span, columns, cell, gap),
                  child: field.child,
                ),
            ],
          );
        },
      ),
    );
  }

  static double _widthFor(int span, int columns, double cell, double gap) {
    final s = span.clamp(1, columns);
    return cell * s + gap * (s - 1);
  }
}
