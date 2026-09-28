import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/config/app_config.dart';
import '../mock/mock_backend.dart';
import 'menu_models.dart';
import 'mock_menu_repository.dart';

/// `GET /me/menu`: the menu tree of the signed-in user.
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
  throw UnimplementedError(
    'HttpMenuRepository arrives in phase 4. '
    'Run with --dart-define=USE_MOCK=true.',
  );
});
