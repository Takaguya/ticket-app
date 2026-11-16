part of 'listings_bloc.dart';

enum ListingsStatus { initial, loading, loaded, failure }

final class ListingsState extends Equatable {
  const ListingsState({
    this.status = ListingsStatus.initial,
    this.listings = const [],
    this.errorMessage,
  });

  final ListingsStatus status;
  final List<Listing> listings;

  /// Why the last load failed; shown when there is nothing else to show.
  final String? errorMessage;

  /// The listings of one kind, e.g. `listingsOf<EventListing>()`.
  List<T> listingsOf<T extends Listing>() => listings.whereType<T>().toList();

  ListingsState copyWith({ListingsStatus? status, String? errorMessage}) {
    return ListingsState(
      status: status ?? this.status,
      listings: listings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, listings, errorMessage];
}
