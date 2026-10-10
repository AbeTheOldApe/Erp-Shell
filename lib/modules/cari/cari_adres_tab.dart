import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/session_controller.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/dialogs/adaptive_dialog.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/responsive_form/responsive_form.dart';
import '../../shared/states/empty_state.dart';
import '../../shared/states/error_state.dart';
import '../../shared/states/skeleton_loader.dart';
import '../module_def.dart';
import 'cari_adres_messages.dart';
import 'cari_info_band.dart';
import 'data/cari_adres_models.dart';
import 'data/cari_adres_repository.dart';

/// Addresses of one saved Cari: a small list of cards, no paging.
///
/// "Yeni adres" needs add, edit needs edit and delete needs delete
/// permission; buttons the user may not use are hidden. For a Cari linked to
/// Netsis all three are hidden and a band says why.
class CariAdresTab extends ConsumerStatefulWidget {
  const CariAdresTab({
    required this.cariId,
    required this.permissions,
    required this.onDirtyChanged,
    super.key,
  });

  final int cariId;

  /// The sub-permissions of the Adresler tab.
  final ModulePermissions permissions;

  /// An address form is open with (or without) unsaved changes.
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<CariAdresTab> createState() => _CariAdresTabState();
}

class _CariAdresTabState extends ConsumerState<CariAdresTab> {
  CariAdresList? _list;
  ApiFailure<CariAdresList>? _failure;
  Object? _error;
  bool _loading = true;

  SessionController get _session => ref.read(sessionProvider.notifier);
  CariAdresRepository get _repository => ref.read(cariAdresRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
      _error = null;
    });
    try {
      final result = await _session.guard(
        () => _repository.list(widget.cariId),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        switch (result) {
          case ApiSuccess<CariAdresList>(:final data):
            _list = data;
          case ApiFailure<CariAdresList>():
            _failure = result;
        }
      });
    } on SessionExpiredException {
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _openForm([CariAdres? adres]) async {
    final result = await showAdresDialog(
      context,
      cariId: widget.cariId,
      adres: adres,
      onDirtyChanged: widget.onDirtyChanged,
    );
    if (!mounted || result == null) return;
    if (result == AdresDialogResult.saved) {
      showSuccess(context, context.l10n.saved);
    }
    await _load();
  }

  Future<void> _delete(CariAdres adres) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmMessage(adres.adresTipi),
      confirmLabel: l10n.actionDelete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;
    try {
      final result = await _session.guard(() => _repository.delete(adres.id!));
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<void>():
          showSuccess(context, l10n.deleted);
          await _load();
        case ApiFailure<void>():
          final view = mapAdresFailure(l10n, result);
          _show(view);
          if (view.refreshList) await _load();
      }
    } on SessionExpiredException {
      // The session dialog takes over.
    } catch (_) {
      if (mounted) showErrorBanner(context, l10n.deleteFailed);
    }
  }

  void _show(AdresFailureView view) {
    final message = view.message;
    if (message == null) return;
    if (view.isInfo) {
      showInfo(context, message);
    } else {
      showErrorBanner(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final type = ref.watch(integrationTypeProvider);

    if (_loading && _list == null) return const SkeletonLoader(rows: 4);
    final failure = _failure;
    if (failure != null) {
      if (failure.messageCode == 1004 && failure.isBusinessRule) {
        return EmptyState(icon: Icons.search_off, title: l10n.recordNotFound);
      }
      return ErrorState(
        message: mapAdresFailure(l10n, failure).message,
        onRetry: _load,
      );
    }
    final list = _list;
    if (_error != null || list == null) return ErrorState(onRetry: _load);

    final readOnly = list.netsisBagli;
    final canAdd = widget.permissions.canAdd && !readOnly;
    final canEdit = widget.permissions.canEdit && !readOnly;
    final canDelete = widget.permissions.canDelete && !readOnly;

    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: [
        if (readOnly) ...[
          CariInfoBand(message: l10n.cariNetsisReadonly),
          SizedBox(height: spacing.md),
        ],
        if (canAdd) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(l10n.adresNew),
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        if (list.items.isEmpty)
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              l10n.adresEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        for (final adres in list.items)
          Card(
            margin: EdgeInsets.only(bottom: spacing.sm),
            child: ListTile(
              title: Text(adres.adresTipi),
              subtitle: Text(adresSummary(l10n, adres, type)),
              isThreeLine: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    IconButton(
                      tooltip: l10n.adresEdit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openForm(adres),
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: l10n.actionDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(adres),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// How the address form was closed, when it was not just dismissed.
enum AdresDialogResult {
  /// Saved: show the success text and reload.
  saved,

  /// The record changed or vanished (1004 / 1005 / 1203): reload.
  refresh,
}

/// Opens the address form: [adres] null for a new one. Full screen on
/// phones. Dismissing a changed form asks first; [onDirtyChanged] follows the
/// unsaved state so the shell can warn when the tab is closed.
Future<AdresDialogResult?> showAdresDialog(
  BuildContext context, {
  required int cariId,
  CariAdres? adres,
  required ValueChanged<bool> onDirtyChanged,
}) async {
  final l10n = context.l10n;
  final form = GlobalKey<_AdresFormState>();
  final result = await showAdaptiveAppDialog<AdresDialogResult>(
    context: context,
    title: adres == null ? l10n.adresNew : l10n.adresEdit,
    maxWidth: 560,
    content: (_) => _AdresForm(
      key: form,
      cariId: cariId,
      adres: adres,
      onDirtyChanged: onDirtyChanged,
    ),
    actions: (_) => [
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
        message: l10n.adresDiscardMessage,
        confirmLabel: l10n.discardChangesConfirm,
      );
    },
  );
  onDirtyChanged(false);
  return result;
}

class _AdresForm extends ConsumerStatefulWidget {
  const _AdresForm({
    required this.cariId,
    required this.adres,
    required this.onDirtyChanged,
    super.key,
  });

  final int cariId;
  final CariAdres? adres;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_AdresForm> createState() => _AdresFormState();
}

class _AdresFormState extends ConsumerState<_AdresForm> {
  final _form = GlobalKey<ResponsiveFormState>();
  final _controllers = <AdresField, TextEditingController>{};
  late final IntegrationType _type = ref.read(integrationTypeProvider);
  late int? _tipiId = widget.adres?.adresTipiId;

  /// Errors from the server, shown until the field is edited.
  Map<AdresField, String> _serverErrors = {};
  bool _saving = false;
  bool _reportedDirty = false;

  @override
  void initState() {
    super.initState();
    for (final field in adresFieldsFor(_type)) {
      _controllers[field] = TextEditingController(
        text: widget.adres?.valueOf(field) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The form has changes that were not saved.
  bool get isDirty {
    if (_tipiId != widget.adres?.adresTipiId) return true;
    return _controllers.entries.any(
      (e) => e.value.text.trim() != (widget.adres?.valueOf(e.key).trim() ?? ''),
    );
  }

  CariAdres _toAdres() => CariAdres(
    id: widget.adres?.id,
    cariId: widget.cariId,
    adresTipiId: _tipiId,
    il: _controllers[AdresField.il]?.text ?? '',
    ilce: _controllers[AdresField.ilce]?.text ?? '',
    mahalle: _controllers[AdresField.mahalle]?.text ?? '',
    cadde: _controllers[AdresField.cadde]?.text ?? '',
    disKapi: _controllers[AdresField.disKapi]?.text ?? '',
    icKapi: _controllers[AdresField.icKapi]?.text ?? '',
    adres: _controllers[AdresField.adres]?.text ?? '',
    postaKodu: _controllers[AdresField.postaKodu]?.text ?? '',
  ).forTenant(_type);

  void _changed(AdresField field) {
    setState(() {
      _serverErrors = {..._serverErrors}
        ..remove(field)
        ..remove(AdresField.form);
    });
    final dirty = isDirty;
    if (dirty != _reportedDirty) {
      _reportedDirty = dirty;
      widget.onDirtyChanged(dirty);
    }
  }

  String? _errorFor(AdresField field) {
    final server = _serverErrors[field];
    if (server != null) return server;
    final issue = validateAdres(_toAdres(), _type)[field];
    return issue == null ? null : adresIssueText(context.l10n, field, issue);
  }

  /// Validates and saves; closes the dialog on success.
  Future<void> submit() async {
    if (_saving) return;
    final l10n = context.l10n;
    final issues = validateAdres(_toAdres(), _type);
    final formIssue = issues[AdresField.form];
    setState(
      () => _serverErrors = {
        if (formIssue != null)
          AdresField.form: adresIssueText(l10n, AdresField.form, formIssue),
      },
    );
    final fieldsValid = _form.currentState?.validate() ?? false;
    if (!fieldsValid || formIssue != null) return;

    setState(() => _saving = true);
    final adres = _toAdres();
    try {
      final result = await ref
          .read(sessionProvider.notifier)
          .guard(
            () => ref.read(cariAdresRepositoryProvider).save(adres, _type),
          );
      if (!mounted) return;
      switch (result) {
        case ApiSuccess<int>():
          Navigator.of(context).pop(AdresDialogResult.saved);
        case ApiFailure<int>():
          final view = mapAdresFailure(l10n, result, sent: adres, type: _type);
          if (view.fieldErrors.isNotEmpty) {
            setState(() => _serverErrors = view.fieldErrors);
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
            Navigator.of(context).pop(AdresDialogResult.refresh);
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

  String _label(AppLocalizations l10n, AdresField field) => switch (field) {
    AdresField.il => l10n.adresFieldIl,
    AdresField.ilce => l10n.adresFieldIlce,
    AdresField.mahalle => l10n.adresFieldMahalle,
    AdresField.cadde => l10n.adresFieldCadde,
    AdresField.disKapi => l10n.adresFieldDisKapi,
    AdresField.icKapi => l10n.adresFieldIcKapi,
    AdresField.adres => l10n.adresFieldAdres,
    AdresField.postaKodu => l10n.adresFieldPostaKodu,
    AdresField.adresTipi => l10n.adresFieldTipi,
    AdresField.form => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final scheme = Theme.of(context).colorScheme;
    final tipler = ref.watch(adresTipleriProvider);

    final formError = _serverErrors[AdresField.form];
    final fields = adresFieldsFor(_type);
    // A required field is marked; Adres is the only one (Netsis).
    bool required(AdresField f) => f == AdresField.adres;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formError != null) ...[
          Text(formError, style: TextStyle(color: scheme.error)),
          SizedBox(height: spacing.md),
        ],
        switch (tipler) {
          AsyncData(:final value) => ResponsiveForm(
            key: _form,
            maxColumns: 2,
            fields: [
              FormFieldSlot.full(
                DropdownButtonFormField<int>(
                  key: const ValueKey('adres-tipi'),
                  initialValue: _tipiId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '${l10n.adresFieldTipi} *',
                  ),
                  items: [
                    for (final tipi in value)
                      DropdownMenuItem(value: tipi.id, child: Text(tipi.ad)),
                  ],
                  onChanged: (id) {
                    _tipiId = id;
                    _changed(AdresField.adresTipi);
                  },
                  validator: (_) => _errorFor(AdresField.adresTipi),
                ),
              ),
              for (final field in fields)
                FormFieldSlot(
                  TextFormField(
                    controller: _controllers[field],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    keyboardType: field == AdresField.postaKodu
                        ? TextInputType.number
                        : null,
                    decoration: InputDecoration(
                      labelText: required(field)
                          ? '${_label(l10n, field)} *'
                          : _label(l10n, field),
                    ),
                    onChanged: (_) => _changed(field),
                    validator: (_) => _errorFor(field),
                  ),
                  span: field == AdresField.adres ? 2 : 1,
                ),
            ],
          ),
          AsyncError() => Column(
            children: [
              Text(l10n.errorLoadFailed),
              SizedBox(height: spacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(adresTipleriProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
          _ => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}
