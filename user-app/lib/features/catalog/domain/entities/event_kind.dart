/// What sort of event it is. Only a marathon asks for runner details; the
/// others go straight to checkout.
enum EventKind {
  marathon(code: 'marathon', label: 'Marathon'),
  concert(code: 'concert', label: 'Concert'),
  show(code: 'show', label: 'Show');

  const EventKind({required this.code, required this.label});

  /// How the Pin API names it.
  final String code;

  /// The small label on a card, the event page and the ticket.
  final String label;

  /// A marathon registers one runner per booking.
  bool get needsRunnerDetails => this == marathon;

  /// The kind with this [code], or null.
  static EventKind? fromCode(String? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}
