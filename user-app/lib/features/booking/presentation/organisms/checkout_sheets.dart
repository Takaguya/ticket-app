import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/promotion.dart';

/// How to pay. Returns the method chosen, or null when closed.
Future<PaymentMethod?> showPaymentMethodSheet(
  BuildContext context, {
  required PaymentMethod selected,
}) {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Payment method', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            for (final method in PaymentMethod.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _Option(
                  icon: paymentIcon(method),
                  title: method.label,
                  subtitle: method.description,
                  selected: method == selected,
                  onTap: () => Navigator.of(context).pop(method),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

IconData paymentIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.abaPay => Icons.account_balance_wallet_outlined,
  PaymentMethod.card => Icons.credit_card_rounded,
};

/// A promo code to type, or an offer to tap. Returns the code, an empty
/// string to remove the code applied, or null when closed.
Future<String?> showPromoCodeSheet(
  BuildContext context, {
  required List<Promotion> offers,
  String? applied,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _PromoSheet(offers: offers, applied: applied),
  );
}

class _PromoSheet extends StatefulWidget {
  const _PromoSheet({required this.offers, required this.applied});

  final List<Promotion> offers;
  final String? applied;

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  String _typed = '';

  void _apply() {
    if (_typed.trim().isNotEmpty) Navigator.of(context).pop(_typed.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Stays above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Promotion', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hintText: 'Promo code',
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      maxLength: 20,
                      onChanged: (value) => _typed = value,
                      onSubmitted: _apply,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 92,
                    child: AppButton(
                      label: 'Apply',
                      shape: AppButtonShape.rounded,
                      height: AppSizes.fieldHeight,
                      onPressed: _apply,
                    ),
                  ),
                ],
              ),
              if (widget.offers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('OFFERS', style: AppTextStyles.fieldLabel),
                const SizedBox(height: AppSpacing.xs),
                for (final offer in widget.offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _Option(
                      icon: Icons.percent_rounded,
                      title: offer.title,
                      subtitle: '${offer.description} · Code ${offer.code}',
                      selected: offer.code == widget.applied,
                      onTap: () => Navigator.of(context).pop(offer.code),
                    ),
                  ),
              ],
              if (widget.applied != null)
                AppButton(
                  label: 'Remove ${widget.applied}',
                  variant: AppButtonVariant.text,
                  foregroundColor: AppColors.danger,
                  onPressed: () => Navigator.of(context).pop(''),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A choice in a sheet: an icon, two lines and a round mark when chosen.
class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.control);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.borderSoft),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.placeholder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
