import '../l10n/generated/app_localizations.dart';
import 'api_exception.dart';
import 'api_result.dart';

/// Text shown to the user for an [ApiFailure].
///
/// Known `MessageCode`s (`docs/api-contract.md` §2) map to ARB texts. A
/// server error always gets the generic text, never details. Unknown codes
/// show the server's own `Message`.
String apiFailureText(AppLocalizations l10n, ApiFailure<Object?> failure) {
  if (failure.isNetworkError) return l10n.apiNetworkError;
  if (failure.isServerError) return l10n.apiMessage2999;
  final mapped = apiMessageForCode(l10n, failure.messageCode);
  if (mapped != null) return mapped;
  return failure.message.isNotEmpty ? failure.message : l10n.apiMessage2999;
}

/// ARB text of a known `MessageCode`, otherwise `null`. Module-specific
/// codes (e.g. 1201–1205 for Cari) are added here as modules arrive.
String? apiMessageForCode(AppLocalizations l10n, int code) => switch (code) {
  1001 => l10n.apiMessage1001,
  1002 => l10n.apiMessage1002,
  1003 => l10n.apiMessage1003,
  1004 => l10n.apiMessage1004,
  1005 => l10n.apiMessage1005,
  2001 => l10n.apiMessage2001,
  2002 => l10n.apiMessage2002,
  2003 => l10n.apiMessage2003,
  2004 => l10n.apiMessage2004,
  2005 => l10n.apiMessage2005,
  2999 => l10n.apiMessage2999,
  _ => null,
};

/// Text for a failed sign-in. A 401 (wrong credentials, locked account)
/// shows the server's own message; the mock API has none.
String loginErrorText(AppLocalizations l10n, Object error) {
  if (error is UnauthorizedException) {
    return error.message.isNotEmpty ? error.message : l10n.loginFailed;
  }
  if (error is ApiException) {
    if (error.statusCode == 429) return l10n.loginTooManyAttempts;
    if (error.statusCode == 0) return l10n.apiNetworkError;
  }
  return l10n.loginUnexpectedError;
}
