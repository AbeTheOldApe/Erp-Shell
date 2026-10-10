import '../../core/l10n/generated/app_localizations.dart';
import '../../core/network/api_messages.dart';
import '../../core/network/api_result.dart';
import 'data/cari_belge_models.dart';

/// How the document screens present a failed [ApiResult].
class BelgeFailureView {
  const BelgeFailureView({
    this.fieldErrors = const {},
    this.rowErrors = const {},
    this.message,
    this.isInfo = false,
    this.refreshList = false,
    this.closeForm = false,
  });

  /// Errors under the header fields; [BelgeField.form] is the form's header.
  final Map<BelgeField, String> fieldErrors;

  /// Errors under the fields of a line, by line index.
  final Map<int, Map<KalemField, String>> rowErrors;

  /// Text for a banner (error) or snackbar ([isInfo]); `null` when the field
  /// errors say everything.
  final String? message;
  final bool isInfo;

  /// The list is out of date (the record changed or vanished).
  final bool refreshList;

  /// Nothing more can be done in the open form.
  final bool closeForm;

  bool get hasFieldErrors => fieldErrors.isNotEmpty || rowErrors.isNotEmpty;
}

/// Text of a [BelgeIssue]; [decimals] is the limit of a number field.
String belgeIssueText(
  AppLocalizations l10n,
  BelgeIssue issue, {
  int decimals = 0,
}) => switch (issue) {
  BelgeIssue.required => l10n.validationRequired,
  BelgeIssue.tooLong => l10n.validationMaxLength(CariBelgeLimits.belgeNo),
  BelgeIssue.invalidNumber => l10n.validationNumber,
  BelgeIssue.tooManyDecimals => l10n.validationMaxDecimals(decimals),
  BelgeIssue.tooLarge => l10n.validationTooLarge,
  BelgeIssue.notPositive => l10n.validationPositive,
  BelgeIssue.negative => l10n.validationNonNegative,
  BelgeIssue.atLeastOneKalem => l10n.belgeKalemRequired,
  BelgeIssue.tooManyKalem => l10n.belgeKalemLimit(CariBelgeLimits.kalemler),
};

/// Text of a line field issue.
String kalemIssueText(
  AppLocalizations l10n,
  KalemField field,
  BelgeIssue issue,
) => belgeIssueText(
  l10n,
  issue,
  decimals: field == KalemField.miktar
      ? CariBelgeLimits.miktarDecimals
      : CariBelgeLimits.tutarDecimals,
);

/// Maps the `MessageCode`s of `docs/api-contract.md` §6B.5. [sent] is the
/// rejected request, used to point at the right field or line; when the
/// client finds nothing wrong, the server's own text goes to the form.
/// There is no `1203` for documents.
BelgeFailureView mapBelgeFailure(
  AppLocalizations l10n,
  ApiFailure<Object?> failure, {
  BelgeDraft? sent,
}) {
  if (failure.isBusinessRule) {
    switch (failure.messageCode) {
      case 1002 || 1003:
        final validation = sent == null ? null : validateBelge(sent);
        if (validation != null && !validation.isValid) {
          return BelgeFailureView(
            fieldErrors: {
              for (final e in validation.header.entries)
                e.key: belgeIssueText(l10n, e.value),
            },
            rowErrors: {
              for (var i = 0; i < validation.rows.length; i++)
                if (validation.rows[i].isNotEmpty)
                  i: {
                    for (final e in validation.rows[i].entries)
                      e.key: kalemIssueText(l10n, e.key, e.value),
                  },
            },
          );
        }
        final text = failure.message.isNotEmpty
            ? failure.message
            : apiMessageForCode(l10n, failure.messageCode)!;
        return BelgeFailureView(fieldErrors: {BelgeField.form: text});
      case 1004:
        return BelgeFailureView(
          message: l10n.recordNotFound,
          isInfo: true,
          refreshList: true,
          closeForm: true,
        );
      case 1005:
        return BelgeFailureView(
          message: l10n.cariAlreadyDeleted,
          isInfo: true,
          refreshList: true,
          closeForm: true,
        );
    }
  }
  return BelgeFailureView(message: apiFailureText(l10n, failure));
}
