import '../../core/auth/auth_models.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/network/api_messages.dart';
import '../../core/network/api_result.dart';
import 'data/cari_adres_models.dart';

/// How the address screens present a failed [ApiResult].
class AdresFailureView {
  const AdresFailureView({
    this.fieldErrors = const {},
    this.message,
    this.isInfo = false,
    this.refreshList = false,
    this.closeForm = false,
  });

  /// Errors shown under the fields; [AdresField.form] is the form's header.
  final Map<AdresField, String> fieldErrors;

  /// Text for a banner (error) or snackbar ([isInfo]); `null` when the field
  /// errors say everything.
  final String? message;
  final bool isInfo;

  /// The list is out of date (the record changed or vanished).
  final bool refreshList;

  /// Nothing more can be done in the open form.
  final bool closeForm;
}

/// Text of an [AdresIssue] for [field].
String adresIssueText(AppLocalizations l10n, AdresField field, AdresIssue i) =>
    switch (i) {
      AdresIssue.required => l10n.validationRequired,
      AdresIssue.tooLong => l10n.validationMaxLength(field.maxLength),
      AdresIssue.postaKodu => l10n.adresPostaKoduInvalid,
      AdresIssue.atLeastOne => l10n.adresAtLeastOne,
    };

/// Maps the `MessageCode`s of `docs/api-contract.md` §6A.4. [sent] and [type]
/// tell what the rejected request contained, to point at the right field.
/// Anything unmapped shows the server's own message.
AdresFailureView mapAdresFailure(
  AppLocalizations l10n,
  ApiFailure<Object?> failure, {
  CariAdres? sent,
  IntegrationType type = IntegrationType.yok,
}) {
  if (failure.isBusinessRule) {
    switch (failure.messageCode) {
      case 1002 || 1003:
        final issues = sent == null
            ? const <AdresField, AdresIssue>{}
            : validateAdres(sent, type);
        if (issues.isNotEmpty) {
          return AdresFailureView(
            fieldErrors: {
              for (final e in issues.entries)
                e.key: adresIssueText(l10n, e.key, e.value),
            },
          );
        }
        // The client found nothing: the server's own text goes to the form.
        final text = failure.message.isNotEmpty
            ? failure.message
            : apiMessageForCode(l10n, failure.messageCode)!;
        return AdresFailureView(fieldErrors: {AdresField.form: text});
      case 1004:
        return AdresFailureView(
          message: l10n.recordNotFound,
          isInfo: true,
          refreshList: true,
          closeForm: true,
        );
      case 1005:
        return AdresFailureView(
          message: l10n.cariAlreadyDeleted,
          isInfo: true,
          refreshList: true,
          closeForm: true,
        );
      case 1203:
        return AdresFailureView(
          message: l10n.apiMessage1203,
          isInfo: true,
          refreshList: true,
          closeForm: true,
        );
    }
  }
  return AdresFailureView(message: apiFailureText(l10n, failure));
}

/// One-line address for the list: the tenant's fields only.
String adresSummary(
  AppLocalizations l10n,
  CariAdres adres,
  IntegrationType type,
) {
  String v(AdresField f) => adres.valueOf(f).trim();
  final area = [
    v(AdresField.ilce),
    v(AdresField.il),
  ].where((s) => s.isNotEmpty);
  final parts = switch (type) {
    IntegrationType.yok => [
      v(AdresField.mahalle),
      v(AdresField.cadde),
      if (v(AdresField.disKapi).isNotEmpty)
        l10n.adresSummaryDisKapi(v(AdresField.disKapi)),
      if (v(AdresField.icKapi).isNotEmpty)
        l10n.adresSummaryIcKapi(v(AdresField.icKapi)),
    ],
    IntegrationType.netsis => [v(AdresField.adres), v(AdresField.postaKodu)],
  };
  return [
    ...parts.where((s) => s.isNotEmpty),
    if (area.isNotEmpty) area.join(' / '),
  ].join(', ');
}
