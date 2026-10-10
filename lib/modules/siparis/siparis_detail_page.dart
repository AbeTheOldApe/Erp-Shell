import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/app_data_grid/app_data_grid.dart';
import '../../shared/breadcrumb/breadcrumb.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/responsive_form/date_form_field.dart';
import '../../shared/responsive_form/responsive_form.dart';
import '../../shared/responsive_scaffold/responsive_scaffold.dart';
import '../../shared/states/empty_state.dart';
import '../../shared/states/error_state.dart';
import '../../shared/states/skeleton_loader.dart';
import '../module_def.dart';
import 'data/siparis_models.dart';
import 'data/siparis_repository.dart';
import 'kalem_dialog.dart';
import 'siparis_labels.dart';

/// Order header form and lines. [id] is null for a new order.
///
/// Buttons follow the permissions: "Kaydet" needs add (new) or edit
/// (existing) permission, "Sil" needs delete permission; without edit
/// permission the form is read-only. `Ctrl+S` saves.
class SiparisDetailPage extends ConsumerStatefulWidget {
  const SiparisDetailPage({
    required this.ctx,
    required this.id,
    required this.onBack,
    required this.onCreated,
    required this.onDirtyChanged,
    super.key,
  });

  final ModuleContext ctx;
  final int? id;

  /// Back to the list (it reloads).
  final VoidCallback onBack;

  /// A new order was saved and got [id].
  final ValueChanged<int> onCreated;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<SiparisDetailPage> createState() => _SiparisDetailPageState();
}

class _SiparisDetailPageState extends ConsumerState<SiparisDetailPage> {
  final _form = GlobalKey<ResponsiveFormState>();
  final _musteri = TextEditingController();
  final _adres = TextEditingController();
  final _not = TextEditingController();
  DateTime? _tarih = DateTime.now();
  SiparisDurum _durum = SiparisDurum.acik;
  List<SiparisKalemi> _kalemler = const [];
  late LocalGridDataSource<SiparisKalemi> _kalemSource = _sourceFor(_kalemler);

  Siparis? _loaded;
  Object? _loadError;
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  bool _showItemsError = false;

  bool get _isNew => widget.id == null;

  bool get _editable {
    final permissions = widget.ctx.permissions;
    return _isNew ? permissions.canAdd : permissions.canEdit;
  }

  SessionController get _session => ref.read(sessionProvider.notifier);
  SiparisRepository get _repository => ref.read(siparisRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  @override
  void dispose() {
    _musteri.dispose();
    _adres.dispose();
    _not.dispose();
    super.dispose();
  }

  static LocalGridDataSource<SiparisKalemi> _sourceFor(
    List<SiparisKalemi> kalemler,
  ) => LocalGridDataSource(
    kalemler,
    fieldValue: (k, field) => switch (field) {
      'urun' => k.urun,
      'miktar' => k.miktar,
      'birimFiyat' => k.birimFiyat,
      'tutar' => k.tutar,
      _ => null,
    },
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final siparis = await _session.guard(() => _repository.get(widget.id!));
      if (!mounted) return;
      _fill(siparis);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  void _fill(Siparis siparis) {
    _loaded = siparis;
    _musteri.text = siparis.musteri;
    _adres.text = siparis.teslimAdresi;
    _not.text = siparis.not;
    _tarih = siparis.tarih;
    _durum = siparis.durum;
    _setKalemler(siparis.kalemler);
  }

  void _setKalemler(List<SiparisKalemi> kalemler) {
    _kalemler = kalemler;
    _kalemSource = _sourceFor(kalemler);
  }

  void _markDirty() {
    if (!_dirty) {
      _dirty = true;
      widget.onDirtyChanged(true);
    }
    setState(() {});
  }

  void _markClean() {
    _dirty = false;
    widget.onDirtyChanged(false);
  }

  Future<void> _editKalem([SiparisKalemi? kalem]) async {
    if (!_editable) return;
    final result = await showKalemDialog(context, kalem: kalem);
    if (result == null || !mounted) return;
    final index = kalem == null ? -1 : _kalemler.indexOf(kalem);
    setState(() {
      _setKalemler(switch (result) {
        KalemSaved(:final kalem) when index < 0 => [..._kalemler, kalem],
        KalemSaved(:final kalem) => [..._kalemler]..[index] = kalem,
        KalemDeleted() => [..._kalemler]..removeAt(index),
      });
      _showItemsError = false;
    });
    _markDirty();
  }

  Future<void> _save() async {
    if (!_editable || _saving) return;
    final l10n = context.l10n;
    final formValid = _form.currentState?.validate() ?? false;
    setState(() => _showItemsError = _kalemler.isEmpty);
    if (!formValid || _kalemler.isEmpty) return;

    final siparis = Siparis(
      id: widget.id,
      no: _loaded?.no ?? '',
      musteri: _musteri.text.trim(),
      tarih: _tarih!,
      durum: _durum,
      teslimAdresi: _adres.text.trim(),
      not: _not.text.trim(),
      kalemler: _kalemler,
    );
    setState(() => _saving = true);
    try {
      final saved = await _session.guard(
        () =>
            _isNew ? _repository.create(siparis) : _repository.update(siparis),
      );
      if (!mounted) return;
      _markClean();
      showSuccess(context, l10n.saved);
      if (_isNew) {
        widget.onCreated(saved.id!);
      } else {
        setState(() => _fill(saved));
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
    if (loaded == null) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmMessage(loaded.no),
      confirmLabel: l10n.actionDelete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;
    try {
      await _session.guard(() => _repository.delete(loaded.id!));
      if (!mounted) return;
      _markClean();
      showSuccess(context, l10n.deleted);
      widget.onBack();
    } on SessionExpiredException {
      // The session dialog takes over.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.deleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final permissions = widget.ctx.permissions;
    final editable = _editable;

    final breadcrumb = Breadcrumb(
      items: [
        BreadcrumbItem(widget.ctx.title, onTap: () => widget.onBack()),
        BreadcrumbItem(_isNew ? l10n.siparisNew : (_loaded?.no ?? '…')),
      ],
    );

    if (_loading) return const SkeletonLoader(rows: 8);
    if (_loadError != null) {
      final notFound =
          _loadError is ApiException &&
          (_loadError! as ApiException).statusCode == 404;
      return ResponsiveScaffold(
        title: breadcrumb,
        body: notFound
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

    final total = _kalemler.fold<double>(0, (sum, k) => sum + k.tutar);

    return ResponsiveScaffold(
      title: breadcrumb,
      actions: [
        if (!_isNew && permissions.canDelete)
          PageAction(
            icon: Icons.delete_outline,
            label: l10n.actionDelete,
            onPressed: _delete,
            destructive: true,
          ),
        if (editable)
          PageAction(
            icon: Icons.save_outlined,
            label: l10n.actionSave,
            onPressed: _saving ? null : _save,
            primary: true,
          ),
      ],
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        },
        child: ListView(
          padding: EdgeInsets.all(spacing.md),
          children: [
            ResponsiveForm(
              key: _form,
              onChanged: _markDirty,
              fields: [
                FormFieldSlot(
                  TextFormField(
                    controller: _musteri,
                    readOnly: !editable,
                    autofocus: _isNew,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.siparisMusteri),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? l10n.validationRequired
                        : null,
                  ),
                ),
                FormFieldSlot(
                  DateFormField(
                    key: ValueKey('tarih-${_loaded?.id}'),
                    label: l10n.siparisTarih,
                    initialValue: _tarih,
                    readOnly: !editable,
                    onChanged: (date) => _tarih = date,
                    validator: (v) =>
                        v == null ? l10n.validationRequired : null,
                  ),
                ),
                FormFieldSlot(
                  DropdownButtonFormField<SiparisDurum>(
                    key: ValueKey('durum-${_loaded?.id}'),
                    initialValue: _durum,
                    decoration: InputDecoration(labelText: l10n.siparisDurum),
                    items: [
                      for (final d in SiparisDurum.values)
                        DropdownMenuItem(
                          value: d,
                          child: Text(durumLabel(l10n, d)),
                        ),
                    ],
                    onChanged: editable
                        ? (d) => _durum = d ?? SiparisDurum.acik
                        : null,
                  ),
                ),
                FormFieldSlot(
                  TextFormField(
                    controller: _adres,
                    readOnly: !editable,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.siparisTeslimAdresi,
                    ),
                  ),
                  span: 2,
                ),
                FormFieldSlot.full(
                  TextFormField(
                    controller: _not,
                    readOnly: !editable,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: l10n.siparisNot),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.md,
              runSpacing: spacing.sm,
              children: [
                Text(l10n.siparisKalemler, style: theme.textTheme.titleMedium),
                Text(
                  l10n.siparisToplam(Formatters.number(total)),
                  style: theme.textTheme.bodyMedium,
                ),
                if (editable)
                  OutlinedButton.icon(
                    onPressed: () => _editKalem(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.kalemAdd),
                  ),
              ],
            ),
            if (_showItemsError)
              Padding(
                padding: EdgeInsets.only(top: spacing.sm),
                child: Text(
                  l10n.siparisNeedsItem,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            SizedBox(height: spacing.sm),
            SizedBox(
              height: 360,
              child: AppDataGrid<SiparisKalemi>(
                gridId: 'kalemler',
                moduleKey: widget.ctx.moduleKey,
                source: _kalemSource,
                pageSize: 50,
                emptyTitle: l10n.kalemEmpty,
                onOpen: editable ? _editKalem : null,
                columns: [
                  AppGridColumn(
                    field: 'urun',
                    title: l10n.kalemUrun,
                    value: (k) => k.urun,
                    width: 260,
                    cardTitle: true,
                  ),
                  AppGridColumn(
                    field: 'miktar',
                    title: l10n.kalemMiktar,
                    value: (k) => k.miktar,
                    kind: GridColumnKind.decimal,
                    width: 120,
                  ),
                  AppGridColumn(
                    field: 'birimFiyat',
                    title: l10n.kalemBirimFiyat,
                    value: (k) => k.birimFiyat,
                    kind: GridColumnKind.money,
                    width: 140,
                  ),
                  AppGridColumn(
                    field: 'tutar',
                    title: l10n.kalemTutar,
                    value: (k) => k.tutar,
                    kind: GridColumnKind.money,
                    width: 150,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
