import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../modules/registry.dart';
import '../mock/mock_backend.dart';
import 'http_menu_repository.dart';
import 'menu_models.dart';
import 'mock_menu_repository.dart';

/// The menu tree of the signed-in user: `GET /me/menu` in mock mode, the
/// client-side definition filtered by `GET /me` in real mode.
abstract class MenuRepository {
  /// Throws `UnauthorizedException` when the access token is not valid.
  Future<List<MenuNode>> fetchMenu();
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockMenuRepository(
      backend: ref.watch(mockBackendProvider),
      bundle: rootBundle,
      accessToken: () => ref.read(sessionProvider).session?.accessToken,
    );
  }
  return HttpMenuRepository(
    client: ref.watch(apiClientProvider),
    registry: () => ref.read(moduleRegistryProvider),
    l10n: () => lookupAppLocalizations(ref.read(localeProvider)),
  );
});
