/// The kinds of tickets Pin sells.
enum TicketCategory {
  events(title: 'Events', tag: 'Event', path: 'events'),
  bus(title: 'Bus', tag: 'Bus', path: 'bus'),
  cinema(title: 'Cinema', tag: 'Cinema', path: 'cinema'),
  admission(title: 'Admission', tag: 'Admission', path: 'admission');

  const TicketCategory({required this.title, required this.tag, required this.path});

  /// Shown on the category's button and page, e.g. "Events".
  final String title;

  /// The small label on a card, e.g. "Event".
  final String tag;

  /// The category's part of a URL, e.g. `/tickets/events`.
  final String path;

  /// The category with this [path], or null.
  static TicketCategory? fromPath(String path) {
    for (final category in values) {
      if (category.path == path) return category;
    }
    return null;
  }
}
