import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/session_controller.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/utils/decimal_units.dart';
import '../../shared/dialogs/adaptive_dialog.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/responsive_form/date_form_field.dart';
import '../../shared/responsive_form/responsive_form.dart';
import 'cari_belge_messages.dart';
import 'data/cari_belge_models.dart';
import 'data/cari_belge_repository.dart';

/// How the document form was closed, when it was not just dismissed.
enum BelgeDialogResult {
  /// Saved: show the success text and reload.
  saved,

  /// The record changed or vanished (1004 / 1005): reload.
  refresh,
}

/// Opens the document form: [belge] null for a new one. Full screen on
/// phones. With [readOnly] the fields cannot be changed and there is no
/// Kaydet. Dismissing a changed form asks first; [onDirtyChanged] follows
/// the unsaved state so the shell can warn when the tab is closed.
Future<BelgeDialogResult?> showBelgeDialog(
  BuildContext context, {
  required int cariId,
  CariBelge? belge,
  bool readOnly = false,
  required ValueChanged<bool> onDirtyChanged,
}) async {
  final l10n = context.l10n;
  final form = GlobalKey<_BelgeFormHostState>();
  final result = await showAdaptiveAppDialog<BelgeDialogResult>(
    context: context,
    title: belge == null
        ? l10n.belgeNew
        : (readOnly ? l10n.belgeView : l10n.belgeEdit),
    maxWidth: 900,
    content: (_) => _BelgeFormHost(
      key: form,
      cariId: cariId,
      belge: belge,
      readOnly: readOnly,
      onDirtyChanged: onDirtyChanged,
    ),
    actions: (_) => [
      if (!readOnly)
        FilledButton(
          onPressed: () => form.currentState?.submit(),
          child: Text(l10n.actionSave),
        ),
    ],
    onWillClose: () async {
      if (!(form.currentState?.isDirty ?? false)) return true;
      return showConfirmDialog(
        context: context,
        title: l10n.discardChangesTitle,
        message: l10n.belgeDiscardMessage,
        confirmLabel: l10n.discardChangesConfirm,
      );
    },
  );
  onDirtyChanged(false);
  return result;
}

/// Waits for the option lists, then shows the form.
class _BelgeFormHost extends ConsumerStatefulWidget {
  const _BelgeFormHost({
    required this.cariId,
    required this.belge,
    required this.readOnly,
    required this.onDirtyChanged,
    super.key,
  });

  final int cariId;
  final CariBelge? belge;
  final bool readOnly;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_BelgeFormHost> createState() => _BelgeFormHostState();
}

class _BelgeFormHostState extends ConsumerState<_BelgeFormHost> {
  final _body = GlobalKey<_BelgeFormBodyState>();

  bool get isDirty => _body.currentState?.isDirty ?? false;

  Future<void> submit() async => _body.currentState?.submit();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return switch (ref.watch(belgeSeceneklerProvider)) {
      AsyncData(:final value) => _BelgeFormBody(
        key: _body,
        cariId: widget.cariId,
        belge: widget.belge,
        readOnly: widget.readOnly,
        options: value,
        onDirtyChanged: widget.onDirtyChanged,
      ),
      AsyncError() => Column(
        children: [
          Text(l10n.errorLoadFailed),
          SizedBox(height: spacing.sm),
          FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(belgeSeceneklerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// A line of the form with its own controllers.
class _Row {
  _Row({
    this.id,
    this.stokKartiId,
    String miktar = '1',
    this.birimId,
    String tutar = '',
  }) : miktar = TextEditingController(text: miktar),
       tutar = TextEditingController(text: tutar);

  final key = UniqueKey();
  final int? id;
  final int? stokKartiId;
  final TextEditingController miktar;
  int? birimId;
  final TextEditingController tutar;

  KalemDraft toDraft() => KalemDraft(
    id: id,
    stokKartiId: stokKartiId,
    miktar: miktar.text,
    birimId: birimId,
    tutar: tutar.text,
  );

  void dispose() {
    miktar.dispose();
    tutar.dispose();
  }
}

class _BelgeFormBody extends ConsumerStatefulWidget {
  const _BelgeFormBody({
    required this.cariId,
    required this.belge,
    required this.readOnly,
    required this.options,
    required this.onDirtyChanged,
    super.key,
  });

  final int cariId;
  final CariBelge? belge;
  final bool readOnly;
  final BelgeSecenekleri options;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_BelgeFormBody> createState() => _BelgeFormBodyState();
}

class _BelgeFormBodyState extends ConsumerState<_BelgeFormBody> {
  final _form = GlobalKey<ResponsiveFormState>();
  final _no = TextEditingController();
  final _rows = <_Row>[];

  /// Rows deleted by the user; disposed with the form (their fields may
  /// still be in the tree for the frame of the deletion).
  final _removed = <_Row>[];
  late final IntegrationType _type = ref.read(integrationTypeProvider);

  int? _tipiId;
  DateTime? _tarih;
  int? _dovizId;
  int? _vadeId;

  late final String _initial;
  bool _reportedDirty = false;
  bool _saving = false;

  /// Errors from the server, shown until the field is edited.
  Map<BelgeField, String> _serverHeader = {};
  Map<int, Map<KalemField, String>> _serverRows = {};
  String? _formError;

  bool get _isNew => widget.belge?.id == null || widget.belge?.id == 0;

  @override
  void initState() {
    super.initState();
    final belge = widget.belge;
    final options = widget.options;
    if (belge != null) {
      _tipiId = belge.tipiId;
      _tarih = belge.tarih;
      _dovizId = belge.dovizId;
      _vadeId = belge.vadeId ?? options.varsayilanVade?.id;
      _no.text = belge.no;
      for (final k in belge.kalemler) {
        _rows.add(
          _Row(
            id: k.id,
            stokKartiId: k.stokKartiId,
            miktar: editableUnits(
              k.miktar,
              decimals: CariBelgeLimits.miktarDecimals,
            ),
            birimId: k.birimId,
            // An empty amount of an old record is asked for before saving.
            tutar: k.tutar == null
                ? ''
                : editableUnits(
                    k.tutar!,
                    decimals: CariBelgeLimits.tutarDecimals,
                  ),
          ),
        );
      }
    } else {
      final today = DateTime.now();
      _tipiId = options.tipler.length == 1 ? options.tipler.first.id : null;
      _tarih = DateTime(today.year, today.month, today.day);
      _dovizId = options.varsayilanDoviz?.id;
      _vadeId = options.varsayilanVade?.id;
      _rows.add(_newRow());
    }
    _initial = _snapshot();
  }

  @override
  void dispose() {
    _no.dispose();
    for (final row in [..._rows, ..._removed]) {
      row.dispose();
    }
    super.dispose();
  }

  _Row _newRow() => _Row(birimId: widget.options.varsayilanBirim?.id);

  String _snapshot() => [
    _tipiId,
    _tarih == null ? '' : isoDate(_tarih!),
    _no.text.trim(),
    _dovizId,
    _vadeId,
    for (final r in _rows)
      '${r.id}/${r.stokKartiId}/${r.miktar.text.trim()}/${r.birimId}/'
          '${r.tutar.text.trim()}',
  ].join('|');

  /// The form has changes that were not saved.
  bool get isDirty => _snapshot() != _initial;

  BelgeDraft _draft() => BelgeDraft(
    id: widget.belge?.id,
    cariId: widget.cariId,
    tipiId: _tipiId,
    no: _no.text,
    tarih: _tarih,
    dovizId: _dovizId,
    vadeId: _vadeId,
    kalemler: [for (final r in _rows) r.toDraft()],
  );

  void _changed({BelgeField? header, int? row, KalemField? field}) {
    setState(() {
      if (header != null) _serverHeader = {..._serverHeader}..remove(header);
      if (row != null && field != null) {
        _serverRows = {
          ..._serverRows,
          row: {...?_serverRows[row]}..remove(field),
        };
      }
      _formError = null;
    });
    final dirty = isDirty;
    if (dirty != _reportedDirty) {
      _reportedDirty = dirty;
      widget.onDirtyChanged(dirty);
    }
  }

  String? _headerError(BelgeField field, BelgeIssue? issue) {
    final server = _serverHeader[field];
    if (server != null) return server;
    return issue == null ? null : belgeIssueText(context.l10n, issue);
  }

  String? _rowError(int index, KalemField field, BelgeIssue? issue) {
    final server = _serverRows[index]?[field];
    if (server != null) return server;
    return issue == null ? null : kalemIssueText(context.l10n, field, issue);
  }

  void _addRow() {
    setState(() {
      _rows.add(_newRow());
      _serverRows = {};
    });
    _changed();
  }

  void _removeRow(int index) {
    final l10n = context.l10n;
    setState(() {
      _removed.add(_rows.removeAt(index));
      _serverRows = {};
    });
    _changed();
    // An existing document may lose its last line; say what that means.
    if (_rows.isEmpty && !_isNew) showInfo(context, l10n.belgeNoKalemInfo);
  }

  /// Validates and saves; closes the dialog on success.
  Future<void> submit() async {
    if (_saving || widget.readOnly) return;
    final l10n = context.l10n;
    final draft = _draft();
    final validation = validateBelge(draft);
    final formIssue = validation.header[BelgeField.form];
    setState(() {
      _serverHeader = {};
      _serverRows = {};
      _formError = formIssue == null ? null : belgeIssueText(l10n, formIssue);
    });
    final fieldsValid = _form.currentState?.validate() ?? false;
    if (!fieldsValid || formIssue != null) return;

    setState(() => _saving = true);
    try {
      final result = await ref
          .read(sessionProvider.notifier)
          .guard(
            () => ref
                .read(cariBelgeRepositoryProvider)
                .save(belgeFromDraft(draft), _type),
          );
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<int>():
          Navigator.of(context).pop(BelgeDialogResult.saved);
        case ApiFailure<int>():
          final view = mapBelgeFailure(l10n, result, sent: draft);
          if (view.hasFieldErrors) {
            setState(() {
              _serverHeader = {...view.fieldErrors}..remove(BelgeField.form);
              _serverRows = view.rowErrors;
              _formError = view.fieldErrors[BelgeField.form];
            });
            _form.currentState?.validate();
          }
          final message = view.message;
          if (message != null) {
            if (view.isInfo) {
              showInfo(context, message);
            } else {
              showErrorBanner(context, message);
            }
          }
          if (view.closeForm) {
            Navigator.of(context).pop(BelgeDialogResult.refresh);
          }
      }
    } on SessionExpiredException {
      // The session dialog takes over; the form stays as it is.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final scheme = Theme.of(context).colorScheme;
    final options = widget.options;
    final readOnly = widget.readOnly;

    // A type that is no longer active is shown while it is the value; once
    // the user picks another type, it cannot be picked again.
    final original = widget.belge;
    final tipler = [
      if (original?.tipiId != null &&
          _tipiId == original!.tipiId &&
          !options.tipler.any((t) => t.id == original.tipiId))
        BelgeTipi(original.tipiId!, original.tipi),
      ...options.tipler,
    ];

    final dovizKodu =
        options.dovizler.where((d) => d.id == _dovizId).firstOrNull?.kod ?? '';
    final total = sumKurus([
      for (final r in _rows)
        parseUnits(r.tutar.text, decimals: CariBelgeLimits.tutarDecimals).value,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveForm(
          key: _form,
          maxColumns: 2,
          fields: [
            FormFieldSlot(
              DropdownButtonFormField<int>(
                key: const ValueKey('belge-tipi'),
                initialValue: _tipiId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${l10n.belgeFieldTipi} *',
                ),
                items: [
                  for (final t in tipler)
                    DropdownMenuItem(value: t.id, child: Text(t.ad)),
                ],
                onChanged: readOnly
                    ? null
                    : (id) {
                        _tipiId = id;
                        _changed(header: BelgeField.tipi);
                      },
                validator: (_) => _headerError(
                  BelgeField.tipi,
                  _tipiId == null ? BelgeIssue.required : null,
                ),
              ),
            ),
            FormFieldSlot(
              DateFormField(
                label: '${l10n.belgeFieldTarih} *',
                initialValue: _tarih,
                readOnly: readOnly,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                onChanged: (date) {
                  _tarih = date;
                  _changed(header: BelgeField.tarih);
                },
                validator: (v) => _headerError(
                  BelgeField.tarih,
                  v == null ? BelgeIssue.required : null,
                ),
              ),
            ),
            FormFieldSlot(
              TextFormField(
                controller: _no,
                readOnly: readOnly,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(labelText: l10n.belgeFieldNo),
                onChanged: (_) => _changed(header: BelgeField.no),
                validator: (v) =>
                    _headerError(BelgeField.no, checkBelgeNo(v ?? '')),
              ),
            ),
            FormFieldSlot(
              DropdownButtonFormField<int>(
                key: const ValueKey('belge-doviz'),
                initialValue: _dovizId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${l10n.belgeFieldDoviz} *',
                ),
                items: [
                  for (final d in options.dovizler)
                    DropdownMenuItem(value: d.id, child: Text(d.kod)),
                ],
                onChanged: readOnly
                    ? null
                    : (id) {
                        _dovizId = id;
                        _changed(header: BelgeField.doviz);
                      },
                validator: (_) => _headerError(
                  BelgeField.doviz,
                  _dovizId == null ? BelgeIssue.required : null,
                ),
              ),
            ),
            FormFieldSlot(
              DropdownButtonFormField<int>(
                key: const ValueKey('belge-vade'),
                initialValue: _vadeId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.belgeFieldVade),
                items: [
                  for (final v in options.vadeler)
                    DropdownMenuItem(value: v.id, child: Text(v.ad)),
                ],
                onChanged: readOnly
                    ? null
                    : (id) {
                        _vadeId = id;
                        _changed(header: BelgeField.vade);
                      },
              ),
            ),
            FormFieldSlot.full(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.belgeKalemler,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (!readOnly)
                        TextButton.icon(
                          onPressed: _rows.length >= CariBelgeLimits.kalemler
                              ? null
                              : _addRow,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.belgeKalemEkle),
                        ),
                    ],
                  ),
                  if (_formError != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.sm),
                      child: Text(
                        _formError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  for (var i = 0; i < _rows.length; i++)
                    _KalemRowView(
                      key: _rows[i].key,
                      row: _rows[i],
                      options: options,
                      showStokKarti: _type == IntegrationType.netsis,
                      readOnly: readOnly,
                      miktarError: (v) =>
                          _rowError(i, KalemField.miktar, checkMiktar(v ?? '')),
                      birimError: (v) => _rowError(
                        i,
                        KalemField.birim,
                        v == null ? BelgeIssue.required : null,
                      ),
                      tutarError: (v) =>
                          _rowError(i, KalemField.tutar, checkTutar(v ?? '')),
                      onChanged: (field) => _changed(row: i, field: field),
                      onRemove: () => _removeRow(i),
                    ),
                  SizedBox(height: spacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${l10n.belgeToplam}: '
                      '${formatUnits(total, decimals: CariBelgeLimits.tutarDecimals)}'
                      '${dovizKodu.isEmpty ? '' : ' $dovizKodu'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line: quantity, unit, amount, the stock card of a Netsis line and
/// the delete button. Stacked on phones.
class _KalemRowView extends StatelessWidget {
  const _KalemRowView({
    required this.row,
    required this.options,
    required this.showStokKarti,
    required this.readOnly,
    required this.miktarError,
    required this.birimError,
    required this.tutarError,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final _Row row;
  final BelgeSecenekleri options;
  final bool showStokKarti;
  final bool readOnly;
  final String? Function(String?) miktarError;
  final String? Function(int?) birimError;
  final String? Function(String?) tutarError;
  final ValueChanged<KalemField> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final compact = Breakpoints.of(context) == WindowSizeClass.compact;

    final miktar = TextFormField(
      controller: row.miktar,
      readOnly: readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: '${l10n.belgeFieldMiktar} *'),
      onChanged: (_) => onChanged(KalemField.miktar),
      validator: miktarError,
    );
    final birim = DropdownButtonFormField<int>(
      initialValue: row.birimId,
      isExpanded: true,
      decoration: InputDecoration(labelText: '${l10n.belgeFieldBirim} *'),
      items: [
        for (final b in options.birimler)
          DropdownMenuItem(value: b.id, child: Text(b.ad)),
      ],
      onChanged: readOnly
          ? null
          : (id) {
              row.birimId = id;
              onChanged(KalemField.birim);
            },
      validator: birimError,
    );
    final tutar = TextFormField(
      controller: row.tutar,
      readOnly: readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: '${l10n.belgeFieldTutar} *'),
      onChanged: (_) => onChanged(KalemField.tutar),
      validator: tutarError,
    );
    final stok = showStokKarti && row.stokKartiId != null
        ? Text(
            l10n.belgeStokKarti(row.stokKartiId!),
            style: Theme.of(context).textTheme.bodySmall,
          )
        : null;
    final delete = readOnly
        ? null
        : IconButton(
            tooltip: l10n.belgeKalemSil,
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          );

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    miktar,
                    SizedBox(height: spacing.sm),
                    birim,
                    SizedBox(height: spacing.sm),
                    tutar,
                    if (stok != null || delete != null)
                      Row(
                        children: [
                          if (stok != null) Expanded(child: stok),
                          if (stok == null) const Spacer(),
                          ?delete,
                        ],
                      ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: miktar),
                    SizedBox(width: spacing.sm),
                    Expanded(flex: 2, child: birim),
                    SizedBox(width: spacing.sm),
                    Expanded(flex: 2, child: tutar),
                    if (stok != null) ...[
                      SizedBox(width: spacing.sm),
                      Padding(
                        padding: EdgeInsets.only(top: spacing.md),
                        child: stok,
                      ),
                    ],
                    ?delete,
                  ],
                ),
        ),
      ),
    );
  }
}
