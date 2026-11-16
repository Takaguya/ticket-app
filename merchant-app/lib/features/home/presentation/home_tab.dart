import 'package:flutter/material.dart';

import '../../auth/domain/entities/staff_role.dart';

/// The main destinations of the app. Each is a branch of the router's tab
/// shell, in this order, so [index] is also the branch index.
enum HomeTab {
  today('Today', Icons.home_outlined),
  scan('Scan', Icons.qr_code_scanner_rounded),
  bookings('Bookings', Icons.receipt_long_outlined),
  finance('Finance', Icons.account_balance_wallet_outlined),
  staff('Staff', Icons.group_outlined);

  const HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Today, Finance and Staff are for owners only.
  bool get ownerOnly => this == today || this == finance || this == staff;

  /// An owner sees every tab. A scanner sees only Scan and Bookings.
  static List<HomeTab> forRole(StaffRole role) {
    return switch (role) {
      StaffRole.owner => values,
      StaffRole.scanner => const [scan, bookings],
    };
  }

  /// Where someone lands after signing in.
  static HomeTab startFor(StaffRole role) => role == StaffRole.owner ? today : scan;
}
