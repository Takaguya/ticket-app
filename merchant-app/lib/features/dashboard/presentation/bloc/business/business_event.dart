part of 'business_bloc.dart';

sealed class BusinessEvent extends Equatable {
  const BusinessEvent();

  @override
  List<Object?> get props => [];
}

/// The signed-in area opened: start following events and bookings.
final class BusinessStarted extends BusinessEvent {
  const BusinessStarted();
}
