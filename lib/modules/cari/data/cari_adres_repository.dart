import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_result.dart';
import 'cari_adres_models.dart';
import 'http_cari_adres_repository.dart';
import 'mock_cari_adres_repository.dart';

/// Cari address API (`docs/api-contract.md` §6A). Outcomes are [ApiResult]s:
/// a business rule rejection (`MessageCode` 1xxx) is a value, not an
/// exception.
abstract class CariAdresRepository {
  /// `1004` when the Cari does not exist.
  Future<ApiResult<CariAdresList>> list(int cariId);

  /// Creates (`adres.id` null) or updates; returns the `CariAdresId`. Only
  /// the fields of [type]'s set are sent.
  Future<ApiResult<int>> save(CariAdres adres, IntegrationType type);

  Future<ApiResult<void>> delete(int id);

  /// The fixed list of address types.
  Future<ApiResult<List<AdresTipi>>> tipler();
}

final cariAdresRepositoryProvider = Provider<CariAdresRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockCariAdresRepository();
  return HttpCariAdresRepository(ref.watch(apiClientProvider));
});

/// The address types, fetched once per session. The list is the same for
/// every tenant; it is dropped when the user signs out or another signs in.
/// A failed fetch is an error value; `ref.invalidate` retries it.
final adresTipleriProvider = FutureProvider<List<AdresTipi>>((ref) async {
  ref.watch(currentUserIdProvider);
  final repository = ref.watch(cariAdresRepositoryProvider);
  final result = await ref
      .read(sessionProvider.notifier)
      .guard(repository.tipler);
  switch (result) {
    case ApiSuccess<List<AdresTipi>>(:final data):
      return data;
    case ApiFailure<List<AdresTipi>>(
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
});
