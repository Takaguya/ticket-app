import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/publish_bus_trip.dart';
import 'cover_photos.dart';

// Events ---------------------------------------------------------------------

sealed class CreateTripEvent extends Equatable {
  const CreateTripEvent();

  @override
  List<Object?> get props => [];
}

final class CreateTripOriginChanged extends CreateTripEvent {
  const CreateTripOriginChanged(this.origin);

  final String origin;

  @override
  List<Object?> get props => [origin];
}

final class CreateTripDestinationChanged extends CreateTripEvent {
  const CreateTripDestinationChanged(this.destination);

  final String destination;

  @override
  List<Object?> get props => [destination];
}

final class CreateTripDateChanged extends CreateTripEvent {
  const CreateTripDateChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

final class CreateTripTimeChanged extends CreateTripEvent {
  const CreateTripTimeChanged({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  List<Object?> get props => [hour, minute];
}

/// The journey time in hours as typed, e.g. `6` or `3.5`.
final class CreateTripDurationChanged extends CreateTripEvent {
  const CreateTripDurationChanged(this.hours);

  final String hours;

  @override
  List<Object?> get props => [hours];
}

final class CreateTripCoachChanged extends CreateTripEvent {
  const CreateTripCoachChanged(this.coach);

  final CoachType coach;

  @override
  List<Object?> get props => [coach];
}

/// The price of a seat in dollars as typed. Empty means free.
final class CreateTripPriceChanged extends CreateTripEvent {
  const CreateTripPriceChanged(this.price);

  final String price;

  @override
  List<Object?> get props => [price];
}

final class CreateTripBoardingPointChanged extends CreateTripEvent {
  const CreateTripBoardingPointChanged(this.point);

  final String point;

  @override
  List<Object?> get props => [point];
}

final class CreateTripBoardingAddressChanged extends CreateTripEvent {
  const CreateTripBoardingAddressChanged(this.address);

  final String address;

  @override
  List<Object?> get props => [address];
}

final class CreateTripAboutChanged extends CreateTripEvent {
  const CreateTripAboutChanged(this.about);

  final String about;

  @override
  List<Object?> get props => [about];
}

/// One thing on board (Wi-Fi, A/C...) was switched on or off.
final class CreateTripAmenityToggled extends CreateTripEvent {
  const CreateTripAmenityToggled(this.amenity);

  final String amenity;

  @override
  List<Object?> get props => [amenity];
}

/// The owner tapped "Choose from gallery" or "Take a photo" for the trip's cover picture.
final class CreateTripPhotoRequested extends CreateTripEvent {
  const CreateTripPhotoRequested(this.source);

  final PhotoSource source;

  @override
  List<Object?> get props => [source];
}

/// The owner took the chosen cover picture off the form.
final class CreateTripPhotoRemoved extends CreateTripEvent {
  const CreateTripPhotoRemoved();
}

/// The owner tapped "Publish trip".
final class CreateTripSubmitted extends CreateTripEvent {
  const CreateTripSubmitted();
}

// State ----------------------------------------------------------------------

enum CreateTripStatus {
  editing,
  submitting,

  /// The trip is published: leave the screen.
  published,
}

final class CreateTripState extends Equatable {
  const CreateTripState({
    this.origin = '',
    this.destination = '',
    this.date,
    this.hour,
    this.minute,
    this.hours = '',
    this.coach = CoachType.seater,
    this.price = '',
    this.boardingPoint = '',
    this.boardingAddress = '',
    this.about = '',
    this.amenities = const [],
    this.photo,
    this.status = CreateTripStatus.editing,
    this.notice,
  });

  /// What a bus company can list as on board, in this order.
  static const amenityOptions = ['Wi-Fi', 'A/C', 'Snack', 'Water', 'Blanket', 'Pillow', 'Toilet'];

  final String origin;
  final String destination;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String hours;
  final CoachType coach;
  final String price;
  final String boardingPoint;
  final String boardingAddress;
  final String about;
  final List<String> amenities;
  /// The cover picture chosen for the trip, uploaded once it is published; null for none.
  final Uint8List? photo;
  final CreateTripStatus status;

  /// One-off message for a toast.
  final String? notice;

  bool get hasTime => hour != null && minute != null;

  /// The journey in minutes, or null when what was typed is not a time.
  int? get durationMinutes {
    final value = double.tryParse(hours.trim().replaceAll(',', '.'));
    if (value == null) return null;
    final minutes = (value * 60).round();
    return minutes >= 10 && minutes <= 24 * 60 ? minutes : null;
  }

  /// Dollars as typed; empty means free. Null when it is not an amount.
  int? get priceCents => price.trim().isEmpty ? 0 : Money.parse(price);

  /// What is still missing, or null when the trip can be published.
  String? get problem {
    if (origin.trim().isEmpty) return 'Enter where the trip starts';
    if (destination.trim().isEmpty) return 'Enter where the trip goes';
    if (origin.trim().toLowerCase() == destination.trim().toLowerCase()) {
      return 'The trip must go somewhere other than where it starts';
    }
    if (date == null || !hasTime) return 'Choose the date and departure time';
    if (durationMinutes == null) return 'Enter how long the trip takes, in hours';
    if (boardingPoint.trim().length < 2) return 'Enter where passengers get on';
    if (priceCents == null) return 'Enter the price of a seat';
    return null;
  }

  bool get isValid => problem == null;

  CreateTripState copyWith({
    String? origin,
    String? destination,
    DateTime? date,
    int? hour,
    int? minute,
    String? hours,
    CoachType? coach,
    String? price,
    String? boardingPoint,
    String? boardingAddress,
    String? about,
    List<String>? amenities,
    Uint8List? Function()? photo,
    CreateTripStatus? status,
    String? Function()? notice,
  }) {
    return CreateTripState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      hours: hours ?? this.hours,
      coach: coach ?? this.coach,
      price: price ?? this.price,
      boardingPoint: boardingPoint ?? this.boardingPoint,
      boardingAddress: boardingAddress ?? this.boardingAddress,
      about: about ?? this.about,
      amenities: amenities ?? this.amenities,
      photo: photo == null ? this.photo : photo(),
      status: status ?? this.status,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [
    origin,
    destination,
    date,
    hour,
    minute,
    hours,
    coach,
    price,
    boardingPoint,
    boardingAddress,
    about,
    amenities,
    photo,
    status,
    notice,
  ];
}

// Bloc -----------------------------------------------------------------------

/// The "Create trip" form of a bus company: route, date, departure time,
/// journey time, coach, price per seat, boarding point and what is on board.
class CreateTripBloc extends Bloc<CreateTripEvent, CreateTripState> {
  CreateTripBloc({required this._publishBusTrip, required this._coverPhotos}) : super(const CreateTripState()) {
    on<CreateTripOriginChanged>((event, emit) => emit(state.copyWith(origin: event.origin)));
    on<CreateTripDestinationChanged>(
      (event, emit) => emit(state.copyWith(destination: event.destination)),
    );
    on<CreateTripDateChanged>((event, emit) => emit(state.copyWith(date: event.date)));
    on<CreateTripTimeChanged>(
      (event, emit) => emit(state.copyWith(hour: event.hour, minute: event.minute)),
    );
    on<CreateTripDurationChanged>((event, emit) => emit(state.copyWith(hours: event.hours)));
    on<CreateTripCoachChanged>((event, emit) => emit(state.copyWith(coach: event.coach)));
    on<CreateTripPriceChanged>((event, emit) => emit(state.copyWith(price: event.price)));
    on<CreateTripBoardingPointChanged>(
      (event, emit) => emit(state.copyWith(boardingPoint: event.point)),
    );
    on<CreateTripBoardingAddressChanged>(
      (event, emit) => emit(state.copyWith(boardingAddress: event.address)),
    );
    on<CreateTripAboutChanged>((event, emit) => emit(state.copyWith(about: event.about)));
    on<CreateTripAmenityToggled>(_onAmenityToggled);
    on<CreateTripPhotoRequested>(_onPhotoRequested);
    on<CreateTripPhotoRemoved>((event, emit) => emit(state.copyWith(photo: () => null)));
    on<CreateTripSubmitted>(_onSubmitted);
  }

  final PublishBusTrip _publishBusTrip;
  final CoverPhotos _coverPhotos;

  Future<void> _onPhotoRequested(CreateTripPhotoRequested event, Emitter<CreateTripState> emit) async {
    if (state.status != CreateTripStatus.editing) return;
    final pick = await _coverPhotos.pick(event.source);
    final problem = pick.problem;
    if (problem != null) {
      _notify(emit, problem);
    } else if (pick.photo != null) {
      emit(state.copyWith(photo: () => pick.photo));
    }
  }

  void _onAmenityToggled(CreateTripAmenityToggled event, Emitter<CreateTripState> emit) {
    final chosen = state.amenities;
    emit(
      state.copyWith(
        amenities: chosen.contains(event.amenity)
            ? [for (final item in chosen) if (item != event.amenity) item]
            : [...chosen, event.amenity],
      ),
    );
  }

  Future<void> _onSubmitted(CreateTripSubmitted event, Emitter<CreateTripState> emit) async {
    if (state.status != CreateTripStatus.editing) return;

    final problem = state.problem;
    if (problem != null) {
      _notify(emit, problem);
      return;
    }

    emit(state.copyWith(status: CreateTripStatus.submitting));
    final date = state.date!;
    final route = '${state.origin.trim()} to ${state.destination.trim()}';
    final result = await _publishBusTrip(
      TripDraft(
        origin: state.origin.trim(),
        destination: state.destination.trim(),
        startsAt: DateTime(date.year, date.month, date.day, state.hour!, state.minute!),
        durationMinutes: state.durationMinutes!,
        coach: state.coach,
        priceCents: state.priceCents!,
        boardingPoint: state.boardingPoint.trim(),
        boardingAddress: state.boardingAddress.trim(),
        about: state.about.trim(),
        // In the order of the options, not of the taps.
        amenities: [
          for (final option in CreateTripState.amenityOptions)
            if (state.amenities.contains(option)) option,
        ],
      ),
    );
    switch (result) {
      case Success(value: final trip):
        // The picture needs the trip to exist: it goes up now, and never loses the trip.
        final photoProblem = await _coverPhotos.upload(trip.id, state.photo);
        emit(
          state.copyWith(
            status: CreateTripStatus.published,
            notice: () => CoverPhotos.publishedNotice(
              trip.approved
                  ? '$route is published and on sale'
                  : '$route is sent to Pin for approval. It goes on sale once approved.',
              photoProblem,
            ),
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(status: CreateTripStatus.editing));
        _notify(emit, failure.message);
    }
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<CreateTripState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
