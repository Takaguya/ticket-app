import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/business_snapshot.dart';
import '../../../domain/usecases/watch_business_snapshot.dart';

part 'business_event.dart';
part 'business_state.dart';

/// Holds the live picture of the business (events and bookings) for the
/// whole signed-in area. Today, Scan, Bookings, Finance and Staff all read
/// from it, so a check-in on one screen shows up on the others at once.
class BusinessBloc extends Bloc<BusinessEvent, BusinessState> {
  BusinessBloc({required this._watchSnapshot}) : super(const BusinessState.loading()) {
    on<BusinessStarted>(_onStarted);
  }

  final WatchBusinessSnapshot _watchSnapshot;

  Future<void> _onStarted(BusinessStarted event, Emitter<BusinessState> emit) {
    return emit.forEach(
      _watchSnapshot(),
      onData: BusinessState.ready,
      onError: (_, _) => const BusinessState.failure(),
    );
  }
}
