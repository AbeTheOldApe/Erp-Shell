import '../../core/auth/permissions.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_result.dart';
import '../../modules/module_def.dart';
import 'client_menu.dart';
import 'menu_models.dart';
import 'menu_repository.dart';

/// Menu for the real API (`docs/api-contract.md` §5). The tree is defined in
/// the shell ([clientMenu]); `GET /me` supplies the grants that filter it and
/// give each module its [ModulePermissions]. Every fetch calls `/me` again,
/// so "Menüyü yenile" picks up permission changes.
class HttpMenuRepository implements MenuRepository {
  HttpMenuRepository({
    required ApiClient client,
    required Map<String, ModuleDef> Function() registry,
    required AppLocalizations Function() l10n,
    List<ClientMenuEntry>? entries,
  }) : _client = client,
       _registry = registry,
       _l10n = l10n,
       _entries = entries ?? clientMenu;

  final ApiClient _client;
  final Map<String, ModuleDef> Function() _registry;
  final AppLocalizations Function() _l10n;
  final List<ClientMenuEntry> _entries;

  @override
  Future<List<MenuNode>> fetchMenu() async {
    final result = await _client.send<ApiGrants>(
      'GET',
      '/me',
      parse: (data) {
        final grants = (data! as Map<String, dynamic>)['Yetkiler'];
        return grants is Map<String, dynamic>
            ? ApiGrants.fromJson(grants)
            : ApiGrants.none;
      },
    );
    switch (result) {
      case ApiSuccess<ApiGrants>(:final data):
        return buildClientMenu(
          entries: _entries,
          grants: data,
          registry: _registry(),
          l10n: _l10n(),
        );
      case ApiFailure<ApiGrants>(
        :final httpStatus,
        :final messageCode,
        :final message,
      ):
        if (httpStatus == 401) {
          throw UnauthorizedException(code: '$messageCode', message: message);
        }
        throw ApiException(
          statusCode: httpStatus,
          code: '$messageCode',
          message: message,
        );
    }
  }
}
