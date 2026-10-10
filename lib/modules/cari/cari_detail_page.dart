import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/breadcrumb/breadcrumb.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/responsive_form/responsive_form.dart';
import '../../shared/responsive_scaffold/responsive_scaffold.dart';
import '../../shared/states/empty_state.dart';
import '../../shared/states/error_state.dart';
import '../../shared/states/skeleton_loader.dart';
import '../module_def.dart';
import 'cari_adres_tab.dart';
import 'cari_info_band.dart';
import 'cari_messages.dart';
import 'data/cari_models.dart';
import 'data/cari_repository.dart';

/// Cari form. [id] is null for a new Cari.
///
/// "Kaydet" needs add (new) or edit (existing) permission, "Sil" needs
/// delete permission; without them the form is read-only. A Cari linked to
/// Netsis is always read-only, without Kaydet and Sil. `Ctrl+S` saves.
class CariDetailPage extends ConsumerStatefulWidget {
  const CariDetailPage({
    required this.ctx,
    required this.id,
    required this.onBack,
    required this.onCreated,
    required this.onDirtyChanged,
    required this.onListStale,
    super.key,
  });

  final ModuleContext ctx;
  final int? id;

  /// Back to the list (it reloads).
  final VoidCallback onBack;

  /// A new Cari was saved and got [id].
  final ValueChanged<int> onCreated;
  final ValueChanged<bool> onDirtyChanged;

  /// The list is out of date (e.g. the record was already deleted).
  final VoidCallback onListStale;

  @override
  ConsumerState<CariDetailPage> createState() => _CariDetailPageState();
}

class _CariDetailPageState extends ConsumerState<CariDetailPage> {
  final _form = GlobalKey<ResponsiveFormState>();
  final _kod = TextEditingController();
  final _cari = TextEditingController();
  final _unvan = TextEditingController();
  final _kisaUnvan = TextEditingController();
  final _web = TextEditingController();
  final _ePosta = TextEditingController();
  final _telefon = TextEditingController();
  final _faks = TextEditingController();
  final _vergiDairesi = TextEditingController();
  final _vergiNo = TextEditingController();
  final _tcKimlikNo = TextEditingController();
  bool _musteri = false;
  bool _urunTedarikcisi = false;
  bool _hizmetTedarikcisi = false;
  bool _otomatikEkstre = false;

  /// Errors from the server, shown under their fields until edited.
  Map<CariField, String> _serverErrors = {};

  Cari? _loaded;
  Object? _loadError;
  bool _notFound = false;
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;

  /// An address form is open with unsaved changes.
  bool _adresDirty = false;
  bool _reportedDirty = false;

  /// 0 = Genel, 1 = Adresler. The addresses are built on first visit and
  /// then kept alive.
  int _tab = 0;
  bool _adreslerOpened = false;

  bool get _isNew => widget.id == null;
  bool get _netsisBagli => _loaded?.netsisBagli ?? false;

  bool get _canWrite {
    final permissions = widget.ctx.permissions;
    return _isNew ? permissions.canAdd : permissions.canEdit;
  }

  /// Fields can be edited and Kaydet is offered.
  bool get _editable => _canWrite && !_netsisBagli;
  bool get _canDelete =>
      !_isNew && widget.ctx.permissions.canDelete && !_netsisBagli;

  SessionController get _session => ref.read(sessionProvider.notifier);
  CariRepository get _repository => ref.read(cariRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  @override
  void dispose() {
    for (final c in [
      _kod,
      _cari,
      _unvan,
      _kisaUnvan,
      _web,
      _ePosta,
      _telefon,
      _faks,
      _vergiDairesi,
      _vergiNo,
      _tcKimlikNo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _notFound = false;
    });
    try {
      final result = await _session.guard(() => _repository.get(widget.id!));
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<Cari>(:final data):
          _fill(data);
          setState(() => _loading = false);
        case ApiFailure<Cari>():
          if (result.messageCode == 1004 && result.isBusinessRule) {
            widget.onListStale();
          }
          setState(() {
            _loading = false;
            _notFound = result.messageCode == 1004 && result.isBusinessRule;
            _loadError = result;
          });
      }
    } on SessionExpiredException {
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  void _fill(Cari cari) {
    _loaded = cari;
    _kod.text = cari.kod;
    _cari.text = cari.cari;
    _unvan.text = cari.unvan;
    _kisaUnvan.text = cari.kisaUnvan;
    _web.text = cari.webAdresi;
    _ePosta.text = cari.ePosta;
    _telefon.text = cari.telefon;
    _faks.text = cari.faks;
    _vergiDairesi.text = cari.vergiDairesi;
    _vergiNo.text = cari.vergiNo;
    _tcKimlikNo.text = cari.tcKimlikNo;
    _musteri = cari.musteri;
    _urunTedarikcisi = cari.urunTedarikcisi;
    _hizmetTedarikcisi = cari.hizmetTedarikcisi;
    _otomatikEkstre = cari.otomatikEkstre;
  }

  void _markDirty() {
    _dirty = true;
    _syncDirty();
    setState(() {});
  }

  void _markClean() {
    _dirty = false;
    _syncDirty();
  }

  void _setAdresDirty(bool value) {
    _adresDirty = value;
    _syncDirty();
  }

  /// The tab is dirty while the general form or an address form has changes.
  void _syncDirty() {
    final value = _dirty || _adresDirty;
    if (value == _reportedDirty) return;
    _reportedDirty = value;
    widget.onDirtyChanged(value);
  }

  Cari _toCari() => Cari(
    id: widget.id,
    kod: _kod.text.trim(),
    cari: _cari.text.trim(),
    unvan: _unvan.text.trim(),
    kisaUnvan: _kisaUnvan.text.trim(),
    webAdresi: _web.text.trim(),
    ePosta: _ePosta.text.trim(),
    telefon: _telefon.text.trim(),
    faks: _faks.text.trim(),
    vergiDairesi: _vergiDairesi.text.trim(),
    vergiNo: _vergiNo.text.trim(),
    tcKimlikNo: _tcKimlikNo.text.trim(),
    musteri: _musteri,
    urunTedarikcisi: _urunTedarikcisi,
    hizmetTedarikcisi: _hizmetTedarikcisi,
    otomatikEkstre: _otomatikEkstre,
    aktif: _loaded?.aktif ?? true,
    netsisBagli: _loaded?.netsisBagli ?? false,
  );

  /// Client-side check with the server's rules (the server checks again).
  String? _check(
    String? value, {
    required int max,
    CariField? field,
    bool required = false,
  }) {
    final l10n = context.l10n;
    final text = (value ?? '').trim();
    if (required && text.isEmpty) return l10n.validationRequired;
    if (text.length > max) return l10n.validationMaxLength(max);
    return field == null ? null : _serverErrors[field];
  }

  void _clearServerError(CariField field) {
    if (_serverErrors.containsKey(field)) {
      _serverErrors = {..._serverErrors}..remove(field);
    }
  }

  Future<void> _save() async {
    if (!_editable || _saving || _tab != 0) return;
    final l10n = context.l10n;
    _serverErrors = {};
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final cari = _toCari();
      final result = await _session.guard(() => _repository.save(cari));
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<int>(:final data):
          _markClean();
          showSuccess(context, l10n.saved);
          if (_isNew) {
            widget.onCreated(data);
          } else {
            widget.onListStale();
            setState(() => _loaded = cari);
          }
        case ApiFailure<int>():
          _showFailure(mapCariFailure(l10n, result));
      }
    } on SessionExpiredException {
      // The session dialog takes over; the form stays as it is.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final loaded = _loaded;
    if (loaded == null || !_canDelete) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmMessage(loaded.unvan),
      confirmLabel: l10n.actionDelete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;
    try {
      final result = await _session.guard(() => _repository.delete(loaded.id!));
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<void>():
          _markClean();
          showSuccess(context, l10n.deleted);
          widget.onBack();
        case ApiFailure<void>():
          final view = mapCariFailure(l10n, result);
          _showFailure(view);
          if (view.notFound || result.messageCode == 1005) {
            _markClean();
            widget.onBack();
          }
      }
    } on SessionExpiredException {
      // The session dialog takes over.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.deleteFailed);
    }
  }

  /// Field errors under the fields; the rest as a banner or snackbar.
  void _showFailure(CariFailureView view) {
    if (view.refreshList) widget.onListStale();
    if (view.fieldErrors.isNotEmpty) {
      setState(() => _serverErrors = view.fieldErrors);
      _form.currentState?.validate();
    }
    final message = view.message;
    if (message == null) return;
    if (view.isInfo) {
      showInfo(context, message);
    } else {
      showErrorBanner(context, message);
    }
  }

  /// Genel / Adresler switch. Adresler waits until the Cari is saved.
  Widget _tabHeader(AppLocalizations l10n) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<int>(
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(l10n.cariTabGenel)),
              ButtonSegment(
                value: 1,
                label: Text(l10n.cariTabAdresler),
                enabled: !_isNew,
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) => setState(() {
              _tab = selection.first;
              if (_tab == 1) _adreslerOpened = true;
            }),
          ),
          if (_isNew) ...[
            SizedBox(height: spacing.xs),
            Text(
              l10n.adresSaveFirst,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final editable = _editable;

    final breadcrumb = Breadcrumb(
      items: [
        BreadcrumbItem(widget.ctx.title, onTap: () => widget.onBack()),
        BreadcrumbItem(_isNew ? l10n.cariNew : (_loaded?.unvan ?? '…')),
      ],
    );

    if (_loading) return const SkeletonLoader(rows: 8);
    if (_loadError != null) {
      return ResponsiveScaffold(
        title: breadcrumb,
        body: _notFound
            ? EmptyState(
                icon: Icons.search_off,
                title: l10n.recordNotFound,
                action: OutlinedButton(
                  onPressed: () => widget.onBack(),
                  child: Text(widget.ctx.title),
                ),
              )
            : ErrorState(onRetry: _load),
      );
    }

    Widget textField(
      TextEditingController controller,
      String label,
      int max, {
      CariField? field,
      bool required = false,
      bool autofocus = false,
      TextInputType? keyboardType,
    }) => TextFormField(
      controller: controller,
      readOnly: !editable,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      autovalidateMode: field == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: required ? '$label *' : label),
      onChanged: field == null ? null : (_) => _clearServerError(field),
      validator: (v) => _check(v, max: max, field: field, required: required),
    );

    Widget checkbox(String label, bool value, ValueChanged<bool> onChanged) =>
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label),
          value: value,
          onChanged: editable
              ? (v) {
                  onChanged(v ?? false);
                  _markDirty();
                }
              : null,
        );

    final showAdresler = widget.ctx.subPermissions('adresler').canView;
    final onGeneral = _tab == 0;

    final general = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          if (_netsisBagli) ...[
            CariInfoBand(message: l10n.cariNetsisReadonly),
            SizedBox(height: spacing.md),
          ],
          ResponsiveForm(
            key: _form,
            onChanged: _markDirty,
            fields: [
              FormFieldSlot(
                textField(
                  _unvan,
                  l10n.cariFieldUnvan,
                  CariLimits.unvan,
                  field: CariField.unvan,
                  required: true,
                  autofocus: _isNew,
                ),
                span: 2,
              ),
              FormFieldSlot(
                textField(
                  _kod,
                  l10n.cariFieldKod,
                  CariLimits.kod,
                  field: CariField.kod,
                ),
              ),
              FormFieldSlot(
                textField(_cari, l10n.cariFieldCari, CariLimits.cari),
                span: 2,
              ),
              FormFieldSlot(
                textField(
                  _kisaUnvan,
                  l10n.cariFieldKisaUnvan,
                  CariLimits.kisaUnvan,
                ),
              ),
              FormFieldSlot(
                textField(
                  _vergiDairesi,
                  l10n.cariFieldVergiDairesi,
                  CariLimits.vergiDairesi,
                ),
              ),
              FormFieldSlot(
                textField(
                  _vergiNo,
                  l10n.cariFieldVergiNo,
                  CariLimits.vergiNo,
                  field: CariField.vergiNo,
                ),
              ),
              FormFieldSlot(
                textField(
                  _tcKimlikNo,
                  l10n.cariFieldTcKimlikNo,
                  CariLimits.tcKimlikNo,
                  field: CariField.tcKimlikNo,
                ),
              ),
              FormFieldSlot(
                textField(
                  _telefon,
                  l10n.cariFieldTelefon,
                  CariLimits.telefon,
                  keyboardType: TextInputType.phone,
                ),
              ),
              FormFieldSlot(
                textField(
                  _faks,
                  l10n.cariFieldFaks,
                  CariLimits.faks,
                  keyboardType: TextInputType.phone,
                ),
              ),
              FormFieldSlot(
                textField(
                  _ePosta,
                  l10n.cariFieldEposta,
                  CariLimits.ePosta,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              FormFieldSlot(
                textField(
                  _web,
                  l10n.cariFieldWeb,
                  CariLimits.webAdresi,
                  keyboardType: TextInputType.url,
                ),
              ),
              FormFieldSlot(
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.cariFieldDurum,
                    border: InputBorder.none,
                  ),
                  child: Text(
                    (_loaded?.aktif ?? true)
                        ? l10n.cariStatusActive
                        : l10n.cariStatusPassive,
                  ),
                ),
              ),
              FormFieldSlot.full(
                Wrap(
                  spacing: spacing.lg,
                  children: [
                    SizedBox(
                      width: 220,
                      child: checkbox(
                        l10n.cariRoleMusteri,
                        _musteri,
                        (v) => _musteri = v,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: checkbox(
                        l10n.cariRoleUrunTedarikci,
                        _urunTedarikcisi,
                        (v) => _urunTedarikcisi = v,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: checkbox(
                        l10n.cariRoleHizmetTedarikci,
                        _hizmetTedarikcisi,
                        (v) => _hizmetTedarikcisi = v,
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: checkbox(
                        l10n.cariFieldOtomatikEkstre,
                        _otomatikEkstre,
                        (v) => _otomatikEkstre = v,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ResponsiveScaffold(
      title: breadcrumb,
      actions: [
        if (onGeneral && _canDelete)
          PageAction(
            icon: Icons.delete_outline,
            label: l10n.actionDelete,
            onPressed: _saving ? null : _delete,
            destructive: true,
          ),
        if (onGeneral && editable)
          PageAction(
            icon: Icons.save_outlined,
            label: l10n.actionSave,
            onPressed: _saving ? null : _save,
            primary: true,
          ),
      ],
      body: showAdresler
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tabHeader(l10n),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    sizing: StackFit.expand,
                    children: [
                      ExcludeFocus(excluding: !onGeneral, child: general),
                      if (_adreslerOpened)
                        ExcludeFocus(
                          excluding: onGeneral,
                          child: CariAdresTab(
                            cariId: widget.id!,
                            permissions: widget.ctx.subPermissions('adresler'),
                            onDirtyChanged: _setAdresDirty,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            )
          : general,
    );
  }
}
