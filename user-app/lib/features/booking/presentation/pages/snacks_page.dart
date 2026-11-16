import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/quantity_row.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/presentation/organisms/price_action_bar.dart';
import '../bloc/snacks/snacks_bloc.dart';
import '../booking_navigation.dart';

/// Snacks to go with cinema seats, or "Skip". Expects a [SnacksBloc] above
/// it.
class SnacksPage extends StatelessWidget {
  const SnacksPage({super.key});

  /// Tile colours, in the order the cinema lists its snacks.
  static const _tileColours = [
    (AppColors.admissionSoft, AppColors.admission),
    (AppColors.eventSoft, AppColors.event),
    (AppColors.rideSoft, AppColors.ride),
    (AppColors.busSoft, AppColors.bus),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SnacksBloc, SnacksState>(
      listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
      listener: (context, state) => AppToast.show(context, state.notice!),
      builder: (context, state) {
        final bloc = context.read<SnacksBloc>();
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: ScreenHeader(
                    title: 'Add snacks',
                    subtitle: state.request.title,
                    onBack: () => context.pop(),
                    trailing: TextButton(
                      onPressed: () => context.openCheckout(state.request.withSnacks(const {})),
                      child: const Text('Skip', style: AppTextStyles.link),
                    ),
                  ),
                ),
                Expanded(
                  child: switch (state.status) {
                    SnacksStatus.loading => const MessageView.loading(),
                    SnacksStatus.failure => MessageView(
                      icon: Icons.fastfood_outlined,
                      title: "Can't show the snacks",
                      message: state.errorMessage,
                      actionLabel: 'Try again',
                      onAction: () => bloc.add(const SnacksStarted()),
                    ),
                    SnacksStatus.ready => ListView(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: [
                        const Text(
                          'Pick them up at the counter with your ticket QR.',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          child: Column(
                            children: [
                              for (final (index, snack) in state.snacks.indexed) ...[
                                if (index > 0) const Divider(height: 1, color: AppColors.divider),
                                QuantityRow(
                                  leading: _LetterTile(
                                    letter: snack.name.characters.first,
                                    colours: _tileColours[index % _tileColours.length],
                                  ),
                                  title: snack.name,
                                  subtitle: snack.description,
                                  price: Money.format(snack.priceCents),
                                  quantity: state.quantityOf(snack),
                                  onAdd: () => bloc.add(SnackAdded(snack)),
                                  onRemove: () => bloc.add(SnackRemoved(snack)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  },
                ),
              ],
            ),
          ),
          bottomNavigationBar: PriceActionBar(
            caption: 'Tickets + snacks',
            price: Money.format(state.totalCents),
            actionLabel: 'Continue',
            onAction: () => context.openCheckout(state.chosen),
          ),
        );
      },
    );
  }
}

/// The snack's first letter on a soft colour, until there are photos.
class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.colours});

  final String letter;
  final (Color, Color) colours;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colours.$1, borderRadius: BorderRadius.circular(12)),
      child: Text(
        letter,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colours.$2),
      ),
    );
  }
}
