import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/payouts.dart';
import '../../domain/usecases/get_payouts.dart';

sealed class PayoutsEvent extends Equatable {
  const PayoutsEvent();

  @override
  List<Object?> get props => [];
}

/// Load, or load again (pull to refresh, "Try again").
final class PayoutsRequested extends PayoutsEvent {
  const PayoutsRequested();
}

enum PayoutsStatus { loading, ready, failure }

final class PayoutsState extends Equatable {
  const PayoutsState({this.status = PayoutsStatus.loading, this.overview, this.message});

  final PayoutsStatus status;

  /// The last loaded payouts; kept while loading again.
  final PayoutsOverview? overview;

  /// Why loading failed.
  final String? message;

  @override
  List<Object?> get props => [status, overview, message];
}

/// What Pin owes the business and has paid, for the Finance screen.
class PayoutsBloc extends Bloc<PayoutsEvent, PayoutsState> {
  PayoutsBloc({required this._getPayouts}) : super(const PayoutsState()) {
    on<PayoutsRequested>(_onRequested);
  }

  final GetPayouts _getPayouts;

  Future<void> _onRequested(PayoutsRequested event, Emitter<PayoutsState> emit) async {
    emit(PayoutsState(overview: state.overview));
    final result = await _getPayouts(const NoParams());
    emit(
      result.when(
        success: (overview) => PayoutsState(status: PayoutsStatus.ready, overview: overview),
        failure: (failure) => PayoutsState(
          status: PayoutsStatus.failure,
          overview: state.overview,
          message: failure.message,
        ),
      ),
    );
  }
}
