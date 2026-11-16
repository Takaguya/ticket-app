import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/publish_event.dart';
import 'cover_photos.dart';

// Events ---------------------------------------------------------------------

sealed class CreateEventEvent extends Equatable {
  const CreateEventEvent();

  @override
  List<Object?> get props => [];
}

final class CreateEventNameChanged extends CreateEventEvent {
  const CreateEventNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class CreateEventDateChanged extends CreateEventEvent {
  const CreateEventDateChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

final class CreateEventTimeChanged extends CreateEventEvent {
  const CreateEventTimeChanged({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  List<Object?> get props => [hour, minute];
}

final class CreateEventVenueChanged extends CreateEventEvent {
  const CreateEventVenueChanged(this.venue);

  final String venue;

  @override
  List<Object?> get props => [venue];
}

final class CreateEventKindChanged extends CreateEventEvent {
  const CreateEventKindChanged(this.kind);

  final EventKind kind;

  @override
  List<Object?> get props => [kind];
}

final class CreateEventTicketTypeAdded extends CreateEventEvent {
  const CreateEventTicketTypeAdded();
}

final class CreateEventTicketTypeRemoved extends CreateEventEvent {
  const CreateEventTicketTypeRemoved(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

/// One field of a ticket type changed. Fields left null are unchanged.
final class CreateEventTicketTypeChanged extends CreateEventEvent {
  const CreateEventTicketTypeChanged(this.id, {this.name, this.price, this.quantity});

  final int id;
  final String? name;
  final String? price;
  final String? quantity;

  @override
  List<Object?> get props => [id, name, price, quantity];
}

/// The owner tapped "Choose from gallery" or "Take a photo" for the event's cover picture.
final class CreateEventPhotoRequested extends CreateEventEvent {
  const CreateEventPhotoRequested(this.source);

  final PhotoSource source;

  @override
  List<Object?> get props => [source];
}

/// The owner took the chosen cover picture off the form.
final class CreateEventPhotoRemoved extends CreateEventEvent {
  const CreateEventPhotoRemoved();
}

/// The owner tapped "Publish event".
final class CreateEventSubmitted extends CreateEventEvent {
  const CreateEventSubmitted();
}

// State ----------------------------------------------------------------------

/// A ticket type as typed, before it is checked and converted.
final class TicketTypeDraft extends Equatable {
  const TicketTypeDraft({required this.id, this.name = '', this.price = '', this.quantity = ''});

  /// Identifies the row on screen; not sent to the server.
  final int id;
  final String name;

  /// Dollars as typed. Empty means free.
  final String price;
  final String quantity;

  int get quantityValue => int.tryParse(quantity) ?? 0;
  int? get priceCents => price.trim().isEmpty ? 0 : Money.parse(price);

  /// A ticket type needs a name and a quantity. The price may be 0.
  bool get isComplete => name.trim().isNotEmpty && quantityValue > 0 && priceCents != null;

  @override
  List<Object?> get props => [id, name, price, quantity];
}

enum CreateEventStatus {
  editing,
  submitting,

  /// The event is on sale: leave the screen.
  published,
}

final class CreateEventState extends Equatable {
  const CreateEventState({
    this.name = '',
    this.date,
    this.hour,
    this.minute,
    this.venue = '',
    this.kind,
    this.ticketTypes = const [TicketTypeDraft(id: 0)],
    this.photo,
    this.status = CreateEventStatus.editing,
    this.notice,
  });

  static const maxTicketTypes = 6;

  final String name;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String venue;

  /// Null until the owner chooses one.
  final EventKind? kind;
  final List<TicketTypeDraft> ticketTypes;

  /// The cover picture chosen for the event, uploaded once it is published; null for none.
  final Uint8List? photo;
  final CreateEventStatus status;

  /// One-off message for a toast.
  final String? notice;

  bool get hasTime => hour != null && minute != null;

  /// The sum of all ticket quantities.
  int get capacity => ticketTypes.fold(0, (sum, type) => sum + type.quantityValue);

  /// What is still missing, or null when the event can be published.
  String? get problem {
    if (name.trim().length < 3) return 'Enter the event name';
    if (date == null || !hasTime) return 'Choose the date and start time';
    if (venue.trim().length < 2) return 'Enter the venue';
    if (kind == null) return 'Choose what kind of event it is';
    if (ticketTypes.isEmpty || ticketTypes.any((type) => !type.isComplete)) {
      return 'Give every ticket type a name and a quantity';
    }
    return null;
  }

  bool get isValid => problem == null;

  CreateEventState copyWith({
    String? name,
    DateTime? date,
    int? hour,
    int? minute,
    String? venue,
    EventKind? kind,
    List<TicketTypeDraft>? ticketTypes,
    Uint8List? Function()? photo,
    CreateEventStatus? status,
    String? Function()? notice,
  }) {
    return CreateEventState(
      name: name ?? this.name,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      venue: venue ?? this.venue,
      kind: kind ?? this.kind,
      ticketTypes: ticketTypes ?? this.ticketTypes,
      photo: photo == null ? this.photo : photo(),
      status: status ?? this.status,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [name, date, hour, minute, venue, kind, ticketTypes, photo, status, notice];
}

// Bloc -----------------------------------------------------------------------

/// The "Create event" form: name, date, start time, venue, kind and 1 to 6
/// ticket types.
class CreateEventBloc extends Bloc<CreateEventEvent, CreateEventState> {
  CreateEventBloc({required this._publishEvent, required this._coverPhotos}) : super(const CreateEventState()) {
    on<CreateEventNameChanged>((event, emit) => emit(state.copyWith(name: event.name)));
    on<CreateEventDateChanged>((event, emit) => emit(state.copyWith(date: event.date)));
    on<CreateEventTimeChanged>(
      (event, emit) => emit(state.copyWith(hour: event.hour, minute: event.minute)),
    );
    on<CreateEventVenueChanged>((event, emit) => emit(state.copyWith(venue: event.venue)));
    on<CreateEventKindChanged>((event, emit) => emit(state.copyWith(kind: event.kind)));
    on<CreateEventTicketTypeAdded>(_onTicketTypeAdded);
    on<CreateEventTicketTypeRemoved>(_onTicketTypeRemoved);
    on<CreateEventTicketTypeChanged>(_onTicketTypeChanged);
    on<CreateEventPhotoRequested>(_onPhotoRequested);
    on<CreateEventPhotoRemoved>((event, emit) => emit(state.copyWith(photo: () => null)));
    on<CreateEventSubmitted>(_onSubmitted);
  }

  final PublishEvent _publishEvent;
  final CoverPhotos _coverPhotos;
  int _nextRowId = 1;

  Future<void> _onPhotoRequested(CreateEventPhotoRequested event, Emitter<CreateEventState> emit) async {
    if (state.status != CreateEventStatus.editing) return;
    final pick = await _coverPhotos.pick(event.source);
    final problem = pick.problem;
    if (problem != null) {
      _notify(emit, problem);
    } else if (pick.photo != null) {
      emit(state.copyWith(photo: () => pick.photo));
    }
  }

  void _onTicketTypeAdded(CreateEventTicketTypeAdded event, Emitter<CreateEventState> emit) {
    if (state.ticketTypes.length >= CreateEventState.maxTicketTypes) {
      _notify(emit, 'Maximum ${CreateEventState.maxTicketTypes} ticket types');
      return;
    }
    emit(
      state.copyWith(ticketTypes: [...state.ticketTypes, TicketTypeDraft(id: _nextRowId++)]),
    );
  }

  void _onTicketTypeRemoved(CreateEventTicketTypeRemoved event, Emitter<CreateEventState> emit) {
    // An event always keeps at least one ticket type.
    if (state.ticketTypes.length <= 1) return;
    emit(
      state.copyWith(
        ticketTypes: state.ticketTypes.where((type) => type.id != event.id).toList(),
      ),
    );
  }

  void _onTicketTypeChanged(CreateEventTicketTypeChanged event, Emitter<CreateEventState> emit) {
    emit(
      state.copyWith(
        ticketTypes: [
          for (final type in state.ticketTypes)
            if (type.id == event.id)
              TicketTypeDraft(
                id: type.id,
                name: event.name ?? type.name,
                price: event.price ?? type.price,
                quantity: event.quantity ?? type.quantity,
              )
            else
              type,
        ],
      ),
    );
  }

  Future<void> _onSubmitted(CreateEventSubmitted event, Emitter<CreateEventState> emit) async {
    if (state.status != CreateEventStatus.editing) return;

    final problem = state.problem;
    if (problem != null) {
      _notify(emit, problem);
      return;
    }

    emit(state.copyWith(status: CreateEventStatus.submitting));
    final date = state.date!;
    final name = state.name.trim();
    final result = await _publishEvent(
      EventDraft(
        name: name,
        startsAt: DateTime(date.year, date.month, date.day, state.hour!, state.minute!),
        venue: state.venue.trim(),
        kind: state.kind,
        ticketTypes: [
          for (final type in state.ticketTypes)
            TicketType(
              name: type.name.trim(),
              priceCents: type.priceCents!,
              quantity: type.quantityValue,
            ),
        ],
      ),
    );
    switch (result) {
      case Success(value: final published):
        // The picture needs the event to exist: it goes up now, and never loses the event.
        final photoProblem = await _coverPhotos.upload(published.id, state.photo);
        emit(
          state.copyWith(
            status: CreateEventStatus.published,
            notice: () => CoverPhotos.publishedNotice(
              published.approved
                  ? '$name is published and on sale'
                  : '$name is sent to Pin for approval. It goes on sale once approved.',
              photoProblem,
            ),
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(status: CreateEventStatus.editing));
        _notify(emit, failure.message);
    }
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<CreateEventState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
