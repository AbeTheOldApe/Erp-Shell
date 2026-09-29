import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../data/mock/mock_backend.dart';
import '../../../shared/app_data_grid/grid_query.dart';
import 'mock_siparis_repository.dart';
import 'siparis_models.dart';

/// Orders API (`docs/menu-schema.md` §5):
/// `POST /siparisler/query`, `GET|PUT|DELETE /siparisler/{id}`,
/// `POST /siparisler`.
abstract class SiparisRepository {
  Future<GridPage<SiparisOzet>> query(GridQuery query);

  /// Throws `ApiException` with status 404 when the order does not exist.
  Future<Siparis> get(int id);

  /// Creates [siparis] and returns it with `id` and `no` assigned.
  Future<Siparis> create(Siparis siparis);

  Future<Siparis> update(Siparis siparis);

  Future<void> delete(int id);
}

final siparisRepositoryProvider = Provider<SiparisRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockSiparisRepository(
      backend: ref.watch(mockBackendProvider),
      accessToken: () => ref.read(sessionProvider).session?.accessToken,
    );
  }
  throw UnimplementedError(
    'HttpSiparisRepository arrives in phase 4. '
    'Run with --dart-define=USE_MOCK=true.',
  );
});

/// Grid source for the order list; API calls go through the session guard
/// (401 → refresh → "sign in again").
class SiparisGridSource implements GridDataSource<SiparisOzet> {
  SiparisGridSource(this._ref);

  final Ref _ref;

  @override
  Future<GridPage<SiparisOzet>> fetch(GridQuery query) => _ref
      .read(sessionProvider.notifier)
      .guard(() => _ref.read(siparisRepositoryProvider).query(query));
}

final siparisGridSourceProvider = Provider<SiparisGridSource>(
  SiparisGridSource.new,
);
