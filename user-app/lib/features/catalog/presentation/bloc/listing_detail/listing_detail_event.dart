part of 'listing_detail_bloc.dart';

sealed class ListingDetailEvent extends Equatable {
  const ListingDetailEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened, or "Try again" was tapped.
final class ListingDetailStarted extends ListingDetailEvent {
  const ListingDetailStarted();
}

/// A film: the person tapped a day.
final class ListingDetailDayChosen extends ListingDetailEvent {
  const ListingDetailDayChosen(this.day);

  final DateTime day;

  @override
  List<Object?> get props => [day];
}

/// A film: the person tapped a showtime.
final class ListingDetailShowtimeChosen extends ListingDetailEvent {
  const ListingDetailShowtimeChosen(this.showtime);

  final Showtime showtime;

  @override
  List<Object?> get props => [showtime];
}
