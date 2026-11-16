import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/publish_screening.dart';
import 'cover_photos.dart';

// Events ---------------------------------------------------------------------

sealed class CreateScreeningEvent extends Equatable {
  const CreateScreeningEvent();

  @override
  List<Object?> get props => [];
}

final class CreateScreeningFilmChanged extends CreateScreeningEvent {
  const CreateScreeningFilmChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

/// The film's rating, e.g. `PG-13`. Choosing the one already chosen clears it.
final class CreateScreeningRatingChosen extends CreateScreeningEvent {
  const CreateScreeningRatingChosen(this.rating);

  final String rating;

  @override
  List<Object?> get props => [rating];
}

final class CreateScreeningGenreChanged extends CreateScreeningEvent {
  const CreateScreeningGenreChanged(this.genre);

  final String genre;

  @override
  List<Object?> get props => [genre];
}

/// The running time in minutes as typed, e.g. `112`.
final class CreateScreeningRuntimeChanged extends CreateScreeningEvent {
  const CreateScreeningRuntimeChanged(this.minutes);

  final String minutes;

  @override
  List<Object?> get props => [minutes];
}

final class CreateScreeningAboutChanged extends CreateScreeningEvent {
  const CreateScreeningAboutChanged(this.about);

  final String about;

  @override
  List<Object?> get props => [about];
}

final class CreateScreeningTheatreChanged extends CreateScreeningEvent {
  const CreateScreeningTheatreChanged(this.theatre);

  final String theatre;

  @override
  List<Object?> get props => [theatre];
}

final class CreateScreeningAreaChanged extends CreateScreeningEvent {
  const CreateScreeningAreaChanged(this.area);

  final String area;

  @override
  List<Object?> get props => [area];
}

final class CreateScreeningHallChanged extends CreateScreeningEvent {
  const CreateScreeningHallChanged(this.hall);

  final String hall;

  @override
  List<Object?> get props => [hall];
}

final class CreateScreeningSizeChanged extends CreateScreeningEvent {
  const CreateScreeningSizeChanged(this.size);

  final HallSize size;

  @override
  List<Object?> get props => [size];
}

final class CreateScreeningDateChanged extends CreateScreeningEvent {
  const CreateScreeningDateChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

final class CreateScreeningTimeChanged extends CreateScreeningEvent {
  const CreateScreeningTimeChanged({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  List<Object?> get props => [hour, minute];
}

/// The price of a seat in dollars as typed. Empty means free.
final class CreateScreeningPriceChanged extends CreateScreeningEvent {
  const CreateScreeningPriceChanged(this.price);

  final String price;

  @override
  List<Object?> get props => [price];
}

/// The owner tapped "Choose from gallery" or "Take a photo" for the screening's cover picture
/// (the film's poster).
final class CreateScreeningPhotoRequested extends CreateScreeningEvent {
  const CreateScreeningPhotoRequested(this.source);

  final PhotoSource source;

  @override
  List<Object?> get props => [source];
}

/// The owner took the chosen cover picture off the form.
final class CreateScreeningPhotoRemoved extends CreateScreeningEvent {
  const CreateScreeningPhotoRemoved();
}

/// The owner tapped "Publish screening".
final class CreateScreeningSubmitted extends CreateScreeningEvent {
  const CreateScreeningSubmitted();
}

// State ----------------------------------------------------------------------

enum CreateScreeningStatus {
  editing,
  submitting,

  /// The screening is published: leave the screen.
  published,
}

final class CreateScreeningState extends Equatable {
  const CreateScreeningState({
    this.filmTitle = '',
    this.rating = '',
    this.genre = '',
    this.runtime = '',
    this.about = '',
    this.theatre = '',
    this.area = '',
    this.hall = '',
    this.size = HallSize.standard,
    this.date,
    this.hour,
    this.minute,
    this.price = '',
    this.photo,
    this.status = CreateScreeningStatus.editing,
    this.notice,
  });

  /// The ratings to choose from, in this order.
  static const ratingOptions = ['G', 'PG', 'PG-13', 'R'];

  final String filmTitle;
  final String rating;
  final String genre;
  final String runtime;
  final String about;
  final String theatre;
  final String area;
  final String hall;
  final HallSize size;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String price;
  /// The cover picture chosen for the screening, uploaded once it is published; null for none.
  final Uint8List? photo;
  final CreateScreeningStatus status;

  /// One-off message for a toast.
  final String? notice;

  bool get hasTime => hour != null && minute != null;

  /// The running time in minutes, or null when what was typed is not one the server accepts.
  int? get runtimeMinutes {
    final value = int.tryParse(runtime.trim());
    return value != null && value >= 10 && value <= 10 * 60 ? value : null;
  }

  /// Dollars as typed; empty means free. Null when it is not an amount.
  int? get priceCents => price.trim().isEmpty ? 0 : Money.parse(price);

  /// What is still missing, or null when the screening can be published.
  String? get problem {
    if (filmTitle.trim().isEmpty) return "Enter the film's title";
    if (runtimeMinutes == null) return 'Enter how long the film runs, in minutes';
    if (theatre.trim().isEmpty) return 'Enter the cinema';
    if (hall.trim().isEmpty) return 'Enter the hall, e.g. Hall 3';
    if (date == null || !hasTime) return 'Choose the date and start time';
    if (priceCents == null) return 'Enter the price of a seat';
    return null;
  }

  bool get isValid => problem == null;

  CreateScreeningState copyWith({
    String? filmTitle,
    String? rating,
    String? genre,
    String? runtime,
    String? about,
    String? theatre,
    String? area,
    String? hall,
    HallSize? size,
    DateTime? date,
    int? hour,
    int? minute,
    String? price,
    Uint8List? Function()? photo,
    CreateScreeningStatus? status,
    String? Function()? notice,
  }) {
    return CreateScreeningState(
      filmTitle: filmTitle ?? this.filmTitle,
      rating: rating ?? this.rating,
      genre: genre ?? this.genre,
      runtime: runtime ?? this.runtime,
      about: about ?? this.about,
      theatre: theatre ?? this.theatre,
      area: area ?? this.area,
      hall: hall ?? this.hall,
      size: size ?? this.size,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      price: price ?? this.price,
      photo: photo == null ? this.photo : photo(),
      status: status ?? this.status,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [
    filmTitle,
    rating,
    genre,
    runtime,
    about,
    theatre,
    area,
    hall,
    size,
    date,
    hour,
    minute,
    price,
    photo,
    status,
    notice,
  ];
}

// Bloc -----------------------------------------------------------------------

/// The "Create screening" form of a cinema: the film, the cinema and hall, the
/// day and time, and the price of a seat.
class CreateScreeningBloc extends Bloc<CreateScreeningEvent, CreateScreeningState> {
  CreateScreeningBloc({required this._publishScreening, required this._coverPhotos})
    : super(const CreateScreeningState()) {
    on<CreateScreeningFilmChanged>((event, emit) => emit(state.copyWith(filmTitle: event.title)));
    on<CreateScreeningRatingChosen>(
      (event, emit) =>
          emit(state.copyWith(rating: state.rating == event.rating ? '' : event.rating)),
    );
    on<CreateScreeningGenreChanged>((event, emit) => emit(state.copyWith(genre: event.genre)));
    on<CreateScreeningRuntimeChanged>(
      (event, emit) => emit(state.copyWith(runtime: event.minutes)),
    );
    on<CreateScreeningAboutChanged>((event, emit) => emit(state.copyWith(about: event.about)));
    on<CreateScreeningTheatreChanged>(
      (event, emit) => emit(state.copyWith(theatre: event.theatre)),
    );
    on<CreateScreeningAreaChanged>((event, emit) => emit(state.copyWith(area: event.area)));
    on<CreateScreeningHallChanged>((event, emit) => emit(state.copyWith(hall: event.hall)));
    on<CreateScreeningSizeChanged>((event, emit) => emit(state.copyWith(size: event.size)));
    on<CreateScreeningDateChanged>((event, emit) => emit(state.copyWith(date: event.date)));
    on<CreateScreeningTimeChanged>(
      (event, emit) => emit(state.copyWith(hour: event.hour, minute: event.minute)),
    );
    on<CreateScreeningPriceChanged>((event, emit) => emit(state.copyWith(price: event.price)));
    on<CreateScreeningPhotoRequested>(_onPhotoRequested);
    on<CreateScreeningPhotoRemoved>((event, emit) => emit(state.copyWith(photo: () => null)));
    on<CreateScreeningSubmitted>(_onSubmitted);
  }

  final PublishScreening _publishScreening;
  final CoverPhotos _coverPhotos;

  Future<void> _onPhotoRequested(
    CreateScreeningPhotoRequested event,
    Emitter<CreateScreeningState> emit,
  ) async {
    if (state.status != CreateScreeningStatus.editing) return;
    final pick = await _coverPhotos.pick(event.source);
    final problem = pick.problem;
    if (problem != null) {
      _notify(emit, problem);
    } else if (pick.photo != null) {
      emit(state.copyWith(photo: () => pick.photo));
    }
  }

  Future<void> _onSubmitted(
    CreateScreeningSubmitted event,
    Emitter<CreateScreeningState> emit,
  ) async {
    if (state.status != CreateScreeningStatus.editing) return;

    final problem = state.problem;
    if (problem != null) {
      _notify(emit, problem);
      return;
    }

    emit(state.copyWith(status: CreateScreeningStatus.submitting));
    final date = state.date!;
    final title = state.filmTitle.trim();
    final result = await _publishScreening(
      ScreeningDraft(
        filmTitle: title,
        runtimeMinutes: state.runtimeMinutes!,
        theatre: state.theatre.trim(),
        theatreArea: state.area.trim(),
        hall: state.hall.trim(),
        hallSize: state.size,
        startsAt: DateTime(date.year, date.month, date.day, state.hour!, state.minute!),
        priceCents: state.priceCents!,
        rating: state.rating,
        genre: state.genre.trim(),
        about: state.about.trim(),
      ),
    );
    switch (result) {
      case Success(value: final screening):
        // The picture needs the screening to exist: it goes up now, and never loses the screening.
        final photoProblem = await _coverPhotos.upload(screening.id, state.photo);
        emit(
          state.copyWith(
            status: CreateScreeningStatus.published,
            notice: () => CoverPhotos.publishedNotice(
              screening.approved
                  ? '$title is published and on sale'
                  : '$title is sent to Pin for approval. It goes on sale once approved.',
              photoProblem,
            ),
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(status: CreateScreeningStatus.editing));
        _notify(emit, failure.message);
    }
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<CreateScreeningState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
