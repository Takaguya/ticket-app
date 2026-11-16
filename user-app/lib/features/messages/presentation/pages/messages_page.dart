import 'package:flutter/material.dart';

import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';

/// The Message tab: e-tickets and booking updates. Empty until booking
/// arrives in the next version of the app.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: 'Message'),
            Expanded(
              child: MessageView(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No messages yet',
                message: 'Your e-tickets and booking updates show up here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
