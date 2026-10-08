import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/app_data_grid/grid_query.dart';
import 'cari_models.dart';
import 'http_cari_repository.dart';
import 'mock_cari_repository.dart';

/// Cari API (`docs/api-contract.md` §6). Outcomes are [ApiResult]s: a
/// business rule rejection (`MessageCode` 1xxx) is a value, not an exception.
abstract class CariRepository {
  /// One page of the list. Filters outside [CariFilters] and any sort are
  /// ignored (the API has no sorting).
  Future<ApiResult<GridPage<CariOzet>>> list(GridQuery query);

  /// `1004` when the Cari does not exist.
  Future<ApiResult<Cari>> get(int id);

  /// Creates (`cari.id` null) or updates; returns the `CariId`.
  Future<ApiResult<int>> save(Cari cari);

  Future<ApiResult<void>> delete(int id);
}

final cariRepositoryProvider = Provider<CariRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockCariRepository();
  return HttpCariRepository(ref.watch(apiClientProvider));
});

/// Grid source of the Cari list. A failed result is thrown so the grid shows
/// its error state; API calls go through the session guard.
class CariGridSource implements GridDataSource<CariOzet> {
  CariGridSource(this._ref);

  final Ref _ref;

  @override
  Future<GridPage<CariOzet>> fetch(GridQuery query) async {
    final result = await _ref
        .read(sessionProvider.notifier)
        .guard(() => _ref.read(cariRepositoryProvider).list(query));
    switch (result) {
      case ApiSuccess<GridPage<CariOzet>>(:final data):
        return data;
      case ApiFailure<GridPage<CariOzet>>(
        :final httpStatus,
        :final messageCode,
        :final message,
      ):
        throw ApiException(
          statusCode: httpStatus,
          code: '$messageCode',
          message: message,
        );
    }
  }
}

final cariGridSourceProvider = Provider<CariGridSource>(CariGridSource.new);
