import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/dialogs/adaptive_dialog.dart';
import '../../shared/responsive_form/responsive_form.dart';
import 'data/siparis_models.dart';

/// Result of the line dialog.
sealed class KalemDialogResult {
  const KalemDialogResult();
}

class KalemSaved extends KalemDialogResult {
  const KalemSaved(this.kalem);

  final SiparisKalemi kalem;
}

class KalemDeleted extends KalemDialogResult {
  const KalemDeleted();
}

/// Adds or edits an order line. Full screen on phones.
Future<KalemDialogResult?> showKalemDialog(
  BuildContext context, {
  SiparisKalemi? kalem,
}) {
  final l10n = context.l10n;
  final form = GlobalKey<_KalemFormState>();
  return showAdaptiveAppDialog<KalemDialogResult>(
    context: context,
    title: kalem == null ? l10n.kalemAdd : l10n.kalemEdit,
    maxWidth: 560,
    content: (_) => _KalemForm(key: form, kalem: kalem),
    actions: (dialogContext) => [
      if (kalem != null)
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(const KalemDeleted()),
          child: Text(l10n.kalemDelete),
        ),
      FilledButton(
        onPressed: () => form.currentState?.submit(),
        child: Text(l10n.actionSave),
      ),
    ],
  );
}

class _KalemForm extends StatefulWidget {
  const _KalemForm({required this.kalem, super.key});

  final SiparisKalemi? kalem;

  @override
  State<_KalemForm> createState() => _KalemFormState();
}

class _KalemFormState extends State<_KalemForm> {
  final _form = GlobalKey<ResponsiveFormState>();
  late final _urun = TextEditingController(text: widget.kalem?.urun ?? '');
  late final _miktar = TextEditingController(
    text: widget.kalem == null ? '' : Formatters.editable(widget.kalem!.miktar),
  );
  late final _fiyat = TextEditingController(
    text: widget.kalem == null
        ? ''
        : Formatters.editable(widget.kalem!.birimFiyat),
  );

  @override
  void dispose() {
    _urun.dispose();
    _miktar.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  /// Validates and closes the dialog with the line.
  void submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      KalemSaved(
        SiparisKalemi(
          urun: _urun.text.trim(),
          miktar: Formatters.tryParseNumber(_miktar.text)!,
          birimFiyat: Formatters.tryParseNumber(_fiyat.text)!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? positive(String? value) {
      final number = Formatters.tryParseNumber(value ?? '');
      if (number == null) return l10n.validationNumber;
      if (number <= 0) return l10n.validationPositive;
      return null;
    }

    return ResponsiveForm(
      key: _form,
      maxColumns: 2,
      fields: [
        FormFieldSlot.full(
          TextFormField(
            controller: _urun,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.kalemUrun),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
          ),
        ),
        FormFieldSlot(
          TextFormField(
            controller: _miktar,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.kalemMiktar),
            validator: positive,
          ),
        ),
        FormFieldSlot(
          TextFormField(
            controller: _fiyat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.kalemBirimFiyat),
            validator: positive,
            onFieldSubmitted: (_) => submit(),
          ),
        ),
      ],
    );
  }
}
