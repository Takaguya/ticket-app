import '../result/result.dart';

/// One business action. Blocs depend on use cases, never on repositories.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// For use cases that take no input.
final class NoParams {
  const NoParams();
}
