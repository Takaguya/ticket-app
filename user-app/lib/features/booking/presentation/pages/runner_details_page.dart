import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../catalog/presentation/organisms/price_action_bar.dart';
import '../../domain/entities/booking_request.dart';
import '../bloc/runner_details/runner_details_bloc.dart';
import '../booking_navigation.dart';
import '../organisms/runner_form.dart';

/// Who runs the race, before checkout. Expects a [RunnerDetailsBloc] above
/// it.
class RunnerDetailsPage extends StatelessWidget {
  const RunnerDetailsPage({super.key, required this.request});

  /// The race and the distance chosen.
  final EventRequest request;

  void _continue(BuildContext context, RunnerDetailsState state) {
    final runner = state.runner;
    if (runner == null) {
      AppToast.show(context, state.problem!);
    } else {
      context.openCheckout(request.withRunner(runner), saveRunner: state.savesToAccount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunnerDetailsBloc, RunnerDetailsState>(
      builder: (context, state) {
        final bloc = context.read<RunnerDetailsBloc>();
        final ready = state.status == RunnerDetailsStatus.ready;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: ScreenHeader(
                    title: 'Runner details',
                    subtitle: request.title,
                    onBack: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: ready
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          child: RunnerForm(
                            state: state,
                            onForSomeoneElseChanged: (value) =>
                                bloc.add(RunnerForSomeoneElseChanged(value)),
                            onTextChanged: (field, value) => bloc.add(RunnerTextChanged(field, value)),
                            onGenderChosen: (gender) => bloc.add(RunnerGenderChosen(gender)),
                            onShirtSizeChosen: (size) => bloc.add(RunnerShirtSizeChosen(size)),
                            onSaveChanged: (save) => bloc.add(RunnerSaveChanged(save)),
                          ),
                        )
                      : const MessageView.loading(),
                ),
              ],
            ),
          ),
          bottomNavigationBar: PriceActionBar(
            caption: request.lines.map((line) => line.name).join(', '),
            price: Money.format(request.subtotalCents),
            actionLabel: 'Continue',
            actionActive: ready && state.problem == null,
            onAction: () => _continue(context, state),
          ),
        );
      },
    );
  }
}
