import '../../../core/error/guard.dart';
import '../../../core/result/result.dart';
import '../domain/entities/payouts.dart';
import '../domain/repositories/payouts_repository.dart';
import 'payouts_api_data_source.dart';

/// [PayoutsRepository] answered by the Pin API.
class ApiPayoutsRepository implements PayoutsRepository {
  const ApiPayoutsRepository(this._api);

  final PayoutsApiDataSource _api;

  @override
  Future<Result<PayoutsOverview>> fetchPayouts() => guard(_api.fetchPayouts);
}
