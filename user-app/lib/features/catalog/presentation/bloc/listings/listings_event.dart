part of 'listings_bloc.dart';

sealed class ListingsEvent extends Equatable {
  const ListingsEvent();

  @override
  List<Object?> get props => [];
}

/// Load the listings: when the page opens, on "Try again" and on pull to refresh.
final class ListingsRequested extends ListingsEvent {
  const ListingsRequested({this.done});

  /// Completed when the load has finished, e.g. to end a pull-to-refresh.
  final Completer<void>? done;
}
