import '../../core/l10n/generated/app_localizations.dart';
import '../../core/network/api_messages.dart';
import '../../core/network/api_result.dart';

/// Form fields a server answer can point at.
enum CariField { unvan, kod, vergiNo, tcKimlikNo }

/// How the Cari screens present a failed [ApiResult].
class CariFailureView {
  const CariFailureView({
    this.fieldErrors = const {},
    this.message,
    this.isInfo = false,
    this.notFound = false,
    this.refreshList = false,
  });

  /// Errors shown under the fields.
  final Map<CariField, String> fieldErrors;

  /// Text for a banner (error) or snackbar ([isInfo]); `null` when the field
  /// errors say everything.
  final String? message;
  final bool isInfo;

  /// `1004`: the record is gone; go back to the list.
  final bool notFound;

  /// The list should be reloaded (the record changed or vanished).
  final bool refreshList;
}

/// Maps the `MessageCode`s of `docs/api-contract.md` §6.5. Anything else
/// falls back to the generic ARB text or the server's own message.
CariFailureView mapCariFailure(
  AppLocalizations l10n,
  ApiFailure<Object?> failure,
) {
  if (failure.isBusinessRule) {
    switch (failure.messageCode) {
      case 1002:
        return CariFailureView(
          fieldErrors: {CariField.unvan: l10n.validationRequired},
        );
      case 1201:
        return CariFailureView(
          fieldErrors: {CariField.kod: l10n.apiMessage1201},
        );
      case 1202:
        return CariFailureView(
          fieldErrors: {
            CariField.vergiNo: l10n.apiMessage1202,
            CariField.tcKimlikNo: l10n.apiMessage1202,
          },
        );
      case 1004:
        return CariFailureView(
          message: l10n.recordNotFound,
          isInfo: true,
          notFound: true,
          refreshList: true,
        );
      case 1005:
        return CariFailureView(
          message: l10n.cariAlreadyDeleted,
          isInfo: true,
          refreshList: true,
        );
      case 1203 || 1204 || 1205:
        return CariFailureView(
          message: apiMessageForCode(l10n, failure.messageCode),
          isInfo: true,
        );
    }
  }
  return CariFailureView(message: apiFailureText(l10n, failure));
}
