import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_result.dart';
import 'cari_belge_models.dart';
import 'http_cari_belge_repository.dart';
import 'mock_cari_belge_repository.dart';

/// Cari document API (`docs/api-contract.md` §6B). Outcomes are
/// [ApiResult]s: a business rule rejection (`MessageCode` 1xxx) is a value,
/// not an exception.
abstract class CariBelgeRepository {
  /// One page, newest first. `1004` when the Cari does not exist.
  Future<ApiResult<BelgeListe>> list(
    int cariId, {
    int page = 1,
    int pageSize = 25,
  });

  /// A document with its lines; `1004` when it does not exist.
  Future<ApiResult<CariBelge>> get(int id);

  /// Creates (`belge.id` null) or updates; the lines are always the whole
  /// list. [type] decides whether `StokKartiId` is sent. Returns the id.
  Future<ApiResult<int>> save(CariBelge belge, IntegrationType type);

  Future<ApiResult<void>> delete(int id);

  /// The fixed lists of the form.
  Future<ApiResult<BelgeSecenekleri>> secenekler();
}

final cariBelgeRepositoryProvider = Provider<CariBelgeRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockCariBelgeRepository();
  return HttpCariBelgeRepository(ref.watch(apiClientProvider));
});

/// The form's lists, fetched once per session and dropped when the user
/// signs out or another signs in. A failed fetch is an error value;
/// `ref.invalidate` retries it.
final belgeSeceneklerProvider = FutureProvider<BelgeSecenekleri>((ref) async {
  ref.watch(currentUserIdProvider);
  final repository = ref.watch(cariBelgeRepositoryProvider);
  final result = await ref
      .read(sessionProvider.notifier)
      .guard(repository.secenekler);
  switch (result) {
    case ApiSuccess<BelgeSecenekleri>(:final data):
      return data;
    case ApiFailure<BelgeSecenekleri>(
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
