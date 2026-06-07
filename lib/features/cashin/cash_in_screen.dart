import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/amount_input.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/party_card.dart';
import '../../core/widgets/result_screen.dart';
import '../../data/models/cash_result.dart';
import '../../data/models/enums.dart';
import 'cash_in_controller.dart';

/// Cash-in (deposit) flow: confirm the customer, then the amount. The agent
/// wallet is debited; the customer wallet is credited (spec §5.4 / §11.1).
class CashInScreen extends ConsumerWidget {
  const CashInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashInControllerProvider);

    if (state.step == CashInStep.done && state.result != null) {
      return _DoneScreen(result: state.result!, customerName: state.customer?.fullName ?? '');
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Dépôt client',
              subtitle: 'Cash-in',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: switch (state.step) {
                CashInStep.lookup ||
                CashInStep.error =>
                  const _LookupStep(),
                _ => const _AmountStep(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupStep extends ConsumerStatefulWidget {
  const _LookupStep();
  @override
  ConsumerState<_LookupStep> createState() => _LookupStepState();
}

class _LookupStepState extends ConsumerState<_LookupStep> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => PhoneValidator.isComplete(_phone.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashInControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const InfoBanner(
          icon: Icons.info_outline,
          text:
              'Saisissez le numéro du client pour confirmer son identité avant le dépôt.',
        ),
        const SizedBox(height: 18),
        const FieldLabel('Numéro du client'),
        const SizedBox(height: 8),
        PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(state.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Rechercher le client',
          size: BtnSize.lg,
          full: true,
          loading: state.looking,
          onPressed: _valid
              ? () => ref
                  .read(cashInControllerProvider.notifier)
                  .lookup(_phone.text)
              : null,
        ),
      ],
    );
  }
}

class _AmountStep extends ConsumerStatefulWidget {
  const _AmountStep();
  @override
  ConsumerState<_AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends ConsumerState<_AmountStep> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashInControllerProvider);
    final notifier = ref.read(cashInControllerProvider.notifier);
    final customer = state.customer;
    final submitting = state.step == CashInStep.submitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (customer != null)
          PartyCard(
            name: customer.fullName,
            subtitle: customer.phonePretty,
            statusLabel: customer.status.frLabel,
            statusActive: customer.status == CustomerStatus.active,
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: submitting ? null : notifier.backToLookup,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text('Changer de client',
                style: AppText.ui(size: 13, color: AppColors.inkMid)),
          ),
        ),
        const SizedBox(height: 18),
        Text('Montant à déposer',
            textAlign: TextAlign.center,
            style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        const SizedBox(height: 18),
        AmountInput(onChanged: notifier.setAmount),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(state.errorMessage!,
              textAlign: TextAlign.center,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 28),
        LipaButton(
          label: state.amount > 0
              ? 'Déposer ${fmtKmf(state.amount)}'
              : 'Déposer',
          size: BtnSize.lg,
          full: true,
          loading: submitting,
          onPressed: state.amount > 0 ? notifier.submit : null,
        ),
        const SizedBox(height: 10),
        Text(
          'Votre float sera débité du montant déposé.',
          textAlign: TextAlign.center,
          style: AppText.ui(size: 12, color: AppColors.inkLow),
        ),
      ],
    );
  }
}

class _DoneScreen extends ConsumerWidget {
  const _DoneScreen({required this.result, required this.customerName});
  final AgentCashInResult result;
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResultScreen(
      title: 'Dépôt',
      headline: 'Dépôt effectué',
      subtitle: customerName.isEmpty
          ? null
          : '${fmtKmf(result.requestedAmount)} crédités à $customerName.',
      replayed: result.replayed,
      onDone: () => Navigator.of(context).pop(),
      detail: LipaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            DetailRow(
                label: 'Montant',
                value: fmtKmf(result.requestedAmount),
                mono: true),
            if (result.feeAmount > 0)
              DetailRow(
                  label: 'Frais', value: fmtKmf(result.feeAmount), mono: true),
            if (result.commissionAmount > 0)
              DetailRow(
                  label: 'Commission',
                  value: fmtKmf(result.commissionAmount),
                  mono: true,
                  valueColor: AppColors.brandDeep),
            DetailRow(
                label: 'Crédité au client',
                value: fmtKmf(result.netAmountToDestination),
                mono: true),
            DetailRow(
                label: 'Réf.',
                value: shortId(result.transactionId),
                mono: true,
                last: true),
          ],
        ),
      ),
    );
  }
}
