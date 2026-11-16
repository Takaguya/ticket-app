part of 'snacks_bloc.dart';

enum SnacksStatus { loading, ready, failure }

final class SnacksState extends Equatable {
  const SnacksState({
    required this.request,
    this.status = SnacksStatus.loading,
    this.snacks = const [],
    this.quantities = const {},
    this.errorMessage,
    this.notice,
  });

  /// The seats chosen so far.
  final CinemaRequest request;
  final SnacksStatus status;

  /// What the cinema sells.
  final List<Snack> snacks;

  /// How many of each are chosen.
  final Map<Snack, int> quantities;

  /// Why the snacks could not be loaded.
  final String? errorMessage;

  /// A one-off message, e.g. that the most of one snack is reached.
  final String? notice;

  int quantityOf(Snack snack) => quantities[snack] ?? 0;

  /// The seats and the snacks chosen.
  CinemaRequest get chosen => request.withSnacks(quantities);

  int get totalCents => chosen.subtotalCents;

  /// Nullable fields that can be cleared take a function.
  SnacksState copyWith({
    SnacksStatus? status,
    List<Snack>? snacks,
    Map<Snack, int>? quantities,
    String? errorMessage,
    String? Function()? notice,
  }) {
    return SnacksState(
      request: request,
      status: status ?? this.status,
      snacks: snacks ?? this.snacks,
      quantities: quantities ?? this.quantities,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [request, status, snacks, quantities, errorMessage, notice];
}
