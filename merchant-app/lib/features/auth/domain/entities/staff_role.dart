/// What a signed-in person may do.
///
/// An owner sees everything. A scanner sees only Scan and Bookings: no door
/// sale, create event, finance, staff or CSV download.
enum StaffRole {
  owner('Owner'),
  scanner('Scanner');

  const StaffRole(this.label);

  final String label;
}
