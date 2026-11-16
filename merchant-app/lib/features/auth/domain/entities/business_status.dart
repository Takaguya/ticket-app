/// Where the business stands with Pin. A new business waits for Pin to
/// approve it; Pin can suspend an approved one.
enum BusinessStatus {
  /// Registered, waiting for Pin. Events can be set up but nothing sells.
  pending,

  /// Approved: sells tickets.
  active,

  /// Stopped by Pin: nothing sells and no events can be published. Tickets
  /// already sold still scan at the entrance.
  suspended;

  /// The status the API sends, or [active] for one this app does not know.
  static BusinessStatus fromName(String? name) {
    for (final status in values) {
      if (status.name == name) return status;
    }
    return active;
  }
}
