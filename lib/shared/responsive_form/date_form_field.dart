import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// Date field with a picker; shows `dd.MM.yyyy`. Takes part in [Form]
/// validation and `Form.onChanged`.
class DateFormField extends FormField<DateTime> {
  DateFormField({
    required String label,
    super.initialValue,
    super.validator,
    ValueChanged<DateTime>? onChanged,
    bool readOnly = false,
    DateTime? firstDate,
    DateTime? lastDate,
    super.key,
  }) : super(
         builder: (field) {
           final value = field.value;
           return Focus(
             child: Builder(
               builder: (context) => InkWell(
                 canRequestFocus: false,
                 onTap: readOnly
                     ? null
                     : () async {
                         Focus.of(context).requestFocus();
                         final picked = await showDatePicker(
                           context: context,
                           initialDate: value ?? DateTime.now(),
                           firstDate: firstDate ?? DateTime(2000),
                           lastDate: lastDate ?? DateTime(2100),
                         );
                         if (picked != null) {
                           field.didChange(picked);
                           onChanged?.call(picked);
                         }
                       },
                 child: InputDecorator(
                   isFocused: Focus.of(context).hasFocus,
                   isEmpty: value == null,
                   decoration: InputDecoration(
                     labelText: label,
                     errorText: field.errorText,
                     enabled: !readOnly,
                     suffixIcon: const Icon(Icons.event),
                   ),
                   child: Text(value == null ? '' : Formatters.date(value)),
                 ),
               ),
             ),
           );
         },
       );
}
