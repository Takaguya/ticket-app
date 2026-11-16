import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// The outcome of an operation that can fail: a value or a [Failure].
///
/// Repositories and use cases return this instead of throwing, so blocs
/// handle both outcomes explicitly.
sealed class Result<T> extends Equatable {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      FailureResult<T>(failure: final f) => failure(f),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
