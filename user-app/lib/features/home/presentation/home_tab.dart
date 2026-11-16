import 'package:flutter/material.dart';

/// The main destinations of the app. Each is a branch of the router's tab
/// shell, in this order, so [index] is also the branch index.
enum HomeTab {
  home('Home', Icons.home_outlined),
  activity('Activity', Icons.receipt_long_outlined),
  messages('Message', Icons.chat_bubble_outline_rounded),
  profile('Profile', Icons.person_outline_rounded);

  const HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
