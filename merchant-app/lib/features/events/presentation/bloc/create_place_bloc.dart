import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/publish_place.dart';
import 'cover_photos.dart';

// Events ---------------------------------------------------------------------

sealed class CreatePlaceEvent extends Equatable {
  const CreatePlaceEvent();

  @override
  List<Object?> get props => [];
}

final class CreatePlaceNameChanged extends CreatePlaceEvent {
  const CreatePlaceNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class CreatePlaceVenueChanged extends CreatePlaceEvent {
  const CreatePlaceVenueChanged(this.venue);

  final String venue;

  @override
  List<Object?> get props => [venue];
}

final class CreatePlaceAddressChanged extends CreatePlaceEvent {
  const CreatePlaceAddressChanged(this.address);

  final String address;

  @override
  List<Object?> get props => [address];
}

final class CreatePlaceAboutChanged extends CreatePlaceEvent {
  const CreatePlaceAboutChanged(this.about);

  final String about;

  @override
  List<Object?> get props => [about];
}

final class CreatePlacePolicyChanged extends CreatePlaceEvent {
  const CreatePlacePolicyChanged(this.policy);

  final String policy;

  @override
  List<Object?> get props => [policy];
}

final class CreatePlaceTicketAdded extends CreatePlaceEvent {
  const CreatePlaceTicketAdded();
}

final class CreatePlaceTicketRemoved extends CreatePlaceEvent {
  const CreatePlaceTicketRemoved(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

/// One field of a ticket type changed. Fields left null are unchanged.
final class CreatePlaceTicketChanged extends CreatePlaceEvent {
  const CreatePlaceTicketChanged(this.id, {this.name, this.description, this.price, this.limit});

  final int id;
  final String? name;
  final String? description;
  final String? price;
  final String? limit;

  @override
  List<Object?> get props => [id, name, description, price, limit];
}

/// The owner tapped "Choose from gallery" or "Take a photo" for the place's cover picture.
final class CreatePlacePhotoRequested extends CreatePlaceEvent {
  const CreatePlacePhotoRequested(this.source);

  final PhotoSource source;

  @override
  List<Object?> get props => [source];
}

/// The owner took the chosen cover picture off the form.
final class CreatePlacePhotoRemoved extends CreatePlaceEvent {
  const CreatePlacePhotoRemoved();
}

/// The owner tapped "Publish place".
final class CreatePlaceSubmitted extends CreatePlaceEvent {
  const CreatePlaceSubmitted();
}

// State ----------------------------------------------------------------------

/// A ticket type of a place as typed, before it is checked and converted.
final class PlaceTicketRow extends Equatable {
  const PlaceTicketRow({
    required this.id,
    this.name = '',
    this.description = '',
    this.price = '',
    this.limit = '',
  });

  /// Identifies the row on screen; not sent to the server.
  final int id;
  final String name;

  /// E.g. "Under 12 · ID required". May be empty.
  final String description;

  /// Dollars as typed. Empty means free.
  final String price;

  /// How many can be sold for one day, as typed. Empty means no limit.
  final String limit;

  int? get priceCents => price.trim().isEmpty ? 0 : Money.parse(price);

  /// The daily limit, or null for none. A limit that is not a whole number of
  /// at least 1 reads as 0, which [isComplete] refuses.
  int? get dailyLimit => limit.trim().isEmpty ? null : int.tryParse(limit.trim()) ?? 0;

  /// A ticket type needs a name and a price (0 is free); a limit, when given, is at least 1.
  bool get isComplete =>
      name.trim().isNotEmpty && priceCents != null && (dailyLimit == null || dailyLimit! >= 1);

  PlaceTicketDraft toDraft() => PlaceTicketDraft(
    name: name.trim(),
    priceCents: priceCents!,
    description: description.trim(),
    dailyLimit: dailyLimit,
  );

  @override
  List<Object?> get props => [id, name, description, price, limit];
}

enum CreatePlaceStatus {
  editing,
  submitting,

  /// The place is published: leave the screen.
  published,
}

final class CreatePlaceState extends Equatable {
  const CreatePlaceState({
    this.name = '',
    this.venue = '',
    this.address = '',
    this.about = '',
    this.policy = '',
    this.tickets = const [PlaceTicketRow(id: 0)],
    this.photo,
    this.status = CreatePlaceStatus.editing,
    this.notice,
  });

  static const maxTickets = 6;

  final String name;
  final String venue;
  final String address;
  final String about;
  final String policy;
  final List<PlaceTicketRow> tickets;

  /// The cover picture chosen for the place, uploaded once it is published; null for none.
  final Uint8List? photo;
  final CreatePlaceStatus status;

  /// One-off message for a toast.
  final String? notice;

  /// What is still missing, or null when the place can be published.
  String? get problem {
    if (name.trim().length < 3) return 'Enter the name of the place';
    if (venue.trim().isEmpty) return 'Enter the venue';
    if (tickets.isEmpty || tickets.any((ticket) => !ticket.isComplete)) {
      return 'Give every ticket type a name; a daily limit is at least 1';
    }
    if (tickets.map((t) => t.name.trim().toLowerCase()).toSet().length != tickets.length) {
      return 'Each ticket type needs a different name';
    }
    return null;
  }

  bool get isValid => problem == null;

  CreatePlaceState copyWith({
    String? name,
    String? venue,
    String? address,
    String? about,
    String? policy,
    List<PlaceTicketRow>? tickets,
    Uint8List? Function()? photo,
    CreatePlaceStatus? status,
    String? Function()? notice,
  }) {
    return CreatePlaceState(
      name: name ?? this.name,
      venue: venue ?? this.venue,
      address: address ?? this.address,
      about: about ?? this.about,
      policy: policy ?? this.policy,
      tickets: tickets ?? this.tickets,
      photo: photo == null ? this.photo : photo(),
      status: status ?? this.status,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [name, venue, address, about, policy, tickets, photo, status, notice];
}

// Bloc -----------------------------------------------------------------------

/// The "Create place" form of an admission business: the place, where it is,
/// what it is about and 1 to 6 kinds of ticket, each with a price and an
/// optional limit per day. There is no date: a place is open every day.
class CreatePlaceBloc extends Bloc<CreatePlaceEvent, CreatePlaceState> {
  CreatePlaceBloc({required this._publishPlace, required this._coverPhotos}) : super(const CreatePlaceState()) {
    on<CreatePlaceNameChanged>((event, emit) => emit(state.copyWith(name: event.name)));
    on<CreatePlaceVenueChanged>((event, emit) => emit(state.copyWith(venue: event.venue)));
    on<CreatePlaceAddressChanged>((event, emit) => emit(state.copyWith(address: event.address)));
    on<CreatePlaceAboutChanged>((event, emit) => emit(state.copyWith(about: event.about)));
    on<CreatePlacePolicyChanged>((event, emit) => emit(state.copyWith(policy: event.policy)));
    on<CreatePlaceTicketAdded>(_onTicketAdded);
    on<CreatePlaceTicketRemoved>(_onTicketRemoved);
    on<CreatePlaceTicketChanged>(_onTicketChanged);
    on<CreatePlacePhotoRequested>(_onPhotoRequested);
    on<CreatePlacePhotoRemoved>((event, emit) => emit(state.copyWith(photo: () => null)));
    on<CreatePlaceSubmitted>(_onSubmitted);
  }

  final PublishPlace _publishPlace;
  final CoverPhotos _coverPhotos;
  int _nextRowId = 1;

  Future<void> _onPhotoRequested(CreatePlacePhotoRequested event, Emitter<CreatePlaceState> emit) async {
    if (state.status != CreatePlaceStatus.editing) return;
    final pick = await _coverPhotos.pick(event.source);
    final problem = pick.problem;
    if (problem != null) {
      _notify(emit, problem);
    } else if (pick.photo != null) {
      emit(state.copyWith(photo: () => pick.photo));
    }
  }

  void _onTicketAdded(CreatePlaceTicketAdded event, Emitter<CreatePlaceState> emit) {
    if (state.tickets.length >= CreatePlaceState.maxTickets) {
      _notify(emit, 'Maximum ${CreatePlaceState.maxTickets} ticket types');
      return;
    }
    emit(state.copyWith(tickets: [...state.tickets, PlaceTicketRow(id: _nextRowId++)]));
  }

  void _onTicketRemoved(CreatePlaceTicketRemoved event, Emitter<CreatePlaceState> emit) {
    // A place always keeps at least one ticket type.
    if (state.tickets.length <= 1) return;
    emit(state.copyWith(tickets: state.tickets.where((t) => t.id != event.id).toList()));
  }

  void _onTicketChanged(CreatePlaceTicketChanged event, Emitter<CreatePlaceState> emit) {
    emit(
      state.copyWith(
        tickets: [
          for (final ticket in state.tickets)
            if (ticket.id == event.id)
              PlaceTicketRow(
                id: ticket.id,
                name: event.name ?? ticket.name,
                description: event.description ?? ticket.description,
                price: event.price ?? ticket.price,
                limit: event.limit ?? ticket.limit,
              )
            else
              ticket,
        ],
      ),
    );
  }

  Future<void> _onSubmitted(CreatePlaceSubmitted event, Emitter<CreatePlaceState> emit) async {
    if (state.status != CreatePlaceStatus.editing) return;

    final problem = state.problem;
    if (problem != null) {
      _notify(emit, problem);
      return;
    }

    emit(state.copyWith(status: CreatePlaceStatus.submitting));
    final name = state.name.trim();
    final result = await _publishPlace(
      PlaceDraft(
        name: name,
        venue: state.venue.trim(),
        venueDetail: state.address.trim(),
        about: state.about.trim(),
        policy: state.policy.trim(),
        tickets: [for (final ticket in state.tickets) ticket.toDraft()],
      ),
    );
    switch (result) {
      case Success(value: final place):
        // The picture needs the place to exist: it goes up now, and never loses the place.
        final photoProblem = await _coverPhotos.upload(place.id, state.photo);
        emit(
          state.copyWith(
            status: CreatePlaceStatus.published,
            notice: () => CoverPhotos.publishedNotice(
              place.approved
                  ? '$name is published and on sale'
                  : '$name is sent to Pin for approval. It goes on sale once approved.',
              photoProblem,
            ),
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(status: CreatePlaceStatus.editing));
        _notify(emit, failure.message);
    }
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<CreatePlaceState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
