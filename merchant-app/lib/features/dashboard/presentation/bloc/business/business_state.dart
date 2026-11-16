part of 'business_bloc.dart';

enum BusinessStatus { loading, ready, failure }

final class BusinessState extends Equatable {
  const BusinessState._({required this.status, this.snapshot});

  const BusinessState.loading() : this._(status: BusinessStatus.loading);

  const BusinessState.ready(BusinessSnapshot snapshot)
    : this._(status: BusinessStatus.ready, snapshot: snapshot);

  const BusinessState.failure() : this._(status: BusinessStatus.failure);

  final BusinessStatus status;

  /// Set when [status] is [BusinessStatus.ready].
  final BusinessSnapshot? snapshot;

  @override
  List<Object?> get props => [status, snapshot];
}
