part of 'snacks_bloc.dart';

sealed class SnacksEvent extends Equatable {
  const SnacksEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened, or "Try again" was tapped.
final class SnacksStarted extends SnacksEvent {
  const SnacksStarted();
}

/// "+" next to a snack.
final class SnackAdded extends SnacksEvent {
  const SnackAdded(this.snack);

  final Snack snack;

  @override
  List<Object?> get props => [snack];
}

/// "–" next to a snack.
final class SnackRemoved extends SnacksEvent {
  const SnackRemoved(this.snack);

  final Snack snack;

  @override
  List<Object?> get props => [snack];
}
