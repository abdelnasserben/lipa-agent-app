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
import '../../core/widgets/pin_sheet.dart';
import '../../core/widgets/result_screen.dart';
import '../../data/models/cash_result.dart';
import '../../data/models/enums.dart';
import 'cash_out_controller.dart';

/// Cash-out (withdrawal) flow with the control-tier loop (spec §8):
/// EXECUTED (200) · PENDING_CONFIRMATION · PENDING_PIN · PENDING_APPROVAL (202).
class CashOutScreen extends ConsumerStatefulWidget {
  const CashOutScreen({super.key});

  @override
  ConsumerState<CashOutScreen> createState() => _CashOutScreenState();
}

class _CashOutScreenState extends ConsumerState<CashOutScreen> {
  bool _pinSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashOutControllerProvider);
    final notifier = ref.read(cashOutControllerProvider.notifier);

    // Drive the merchant-PIN sheet from the control step.
    ref.listen(cashOutControllerProvider, (prev, next) {
      if (next.step == CashOutStep.needsPin && !_pinSheetOpen) {
        _openPinSheet();
      }
    });

    if (state.step == CashOutStep.done && state.result != null) {
      return _DoneScreen(
          result: state.result!,
          merchantName: state.merchant?.businessName ?? '');
    }
    if (state.step == CashOutStep.approval && state.result != null) {
      return _ApprovalScreen(result: state.result!);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Retrait marchand',
              subtitle: 'Cash-out',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: state.step == CashOutStep.lookup
                  ? const _LookupStep()
                  : _AmountStep(onAcknowledge: notifier.acknowledgeConfirmation),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPinSheet() async {
    _pinSheetOpen = true;
    final notifier = ref.read(cashOutControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(builder: (ctx, ref, _) {
          final s = ref.watch(cashOutControllerProvider);
          return PinSheet(
            title: 'PIN du marchand',
            subtitle:
                'Demandez au marchand de saisir son PIN pour autoriser le retrait de ${fmtKmf(s.amount)}.',
            submitting: s.submitting,
            errorMessage: s.pinError,
            onSubmit: (pin) => notifier.submitPin(pin),
          );
        });
      },
    );
    _pinSheetOpen = false;
    // If we left the PIN step without executing (e.g. user dismissed via the
    // close button), reset back to amount so the flow isn't stuck.
    final s = ref.read(cashOutControllerProvider);
    if (s.step == CashOutStep.needsPin) {
      ref.read(cashOutControllerProvider.notifier).backToLookupAmount();
    }
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
    final state = ref.watch(cashOutControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const InfoBanner(
          icon: Icons.info_outline,
          text:
              'Saisissez le numéro du marchand pour confirmer le bénéficiaire du retrait.',
        ),
        const SizedBox(height: 18),
        const FieldLabel('Numéro du marchand'),
        const SizedBox(height: 8),
        PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(state.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Rechercher le marchand',
          size: BtnSize.lg,
          full: true,
          loading: state.looking,
          onPressed: _valid
              ? () => ref
                  .read(cashOutControllerProvider.notifier)
                  .lookup(_phone.text)
              : null,
        ),
      ],
    );
  }
}

class _AmountStep extends ConsumerWidget {
  const _AmountStep({required this.onAcknowledge});
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashOutControllerProvider);
    final notifier = ref.read(cashOutControllerProvider.notifier);
    final merchant = state.merchant;
    final submitting = state.submitting;
    final needsConfirm = state.step == CashOutStep.needsConfirmation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (merchant != null)
          PartyCard(
            icon: Icons.storefront_rounded,
            name: merchant.businessName,
            subtitle: '${merchant.externalRef} · ${merchant.phonePretty}',
            statusLabel: merchant.canCashOut
                ? merchant.status.frLabel
                : 'Retrait bloqué',
            statusActive: merchant.canCashOut &&
                merchant.status == MerchantStatus.active,
          ),
        if (merchant != null && !merchant.canCashOut) ...[
          const SizedBox(height: 12),
          const InfoBanner(
            kind: PillKind.warn,
            icon: Icons.block,
            text: 'Ce marchand n’est pas autorisé à effectuer des retraits.',
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: submitting ? null : notifier.backToLookup,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text('Changer de marchand',
                style: AppText.ui(size: 13, color: AppColors.inkMid)),
          ),
        ),
        const SizedBox(height: 18),
        Text('Montant à retirer',
            textAlign: TextAlign.center,
            style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        const SizedBox(height: 18),
        AmountInput(onChanged: notifier.setAmount),
        if (needsConfirm && state.result != null) ...[
          const SizedBox(height: 18),
          InfoBanner(
            kind: PillKind.warn,
            icon: Icons.verified_user_outlined,
            text:
                'Montant supérieur au seuil de ${fmtKmf(state.result!.matchedThresholdAmount ?? 0)}. Confirmez pour poursuivre.',
          ),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(state.errorMessage!,
              textAlign: TextAlign.center,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 28),
        LipaButton(
          label: needsConfirm
              ? 'Confirmer le retrait'
              : (state.amount > 0
                  ? 'Retirer ${fmtKmf(state.amount)}'
                  : 'Retirer'),
          size: BtnSize.lg,
          full: true,
          loading: submitting,
          variant: needsConfirm ? BtnVariant.primaryDark : BtnVariant.primary,
          onPressed: state.amount > 0 && (merchant?.canCashOut ?? false)
              ? (needsConfirm ? onAcknowledge : notifier.submit)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          'Le marchand est débité, votre float est crédité.',
          textAlign: TextAlign.center,
          style: AppText.ui(size: 12, color: AppColors.inkLow),
        ),
      ],
    );
  }
}

class _ApprovalScreen extends ConsumerWidget {
  const _ApprovalScreen({required this.result});
  final AgentCashOutResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResultScreen(
      title: 'Retrait',
      kind: ResultKind.pending,
      headline: 'Approbation requise',
      subtitle:
          'Ce retrait de ${fmtKmf(result.requestedAmount ?? 0)} dépasse le seuil et a été transmis au back-office pour approbation. Aucun mouvement n’a encore eu lieu.',
      onDone: () => Navigator.of(context).pop(),
      detail: LipaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            DetailRow(
                label: 'Montant',
                value: fmtKmf(result.requestedAmount ?? 0),
                mono: true),
            if (result.matchedThresholdAmount != null)
              DetailRow(
                  label: 'Seuil',
                  value: fmtKmf(result.matchedThresholdAmount!),
                  mono: true),
            if (result.approvalId != null)
              DetailRow(
                  label: 'Réf. approbation',
                  value: shortId(result.approvalId!),
                  mono: true,
                  last: true),
          ],
        ),
      ),
    );
  }
}

class _DoneScreen extends ConsumerWidget {
  const _DoneScreen({required this.result, required this.merchantName});
  final AgentCashOutResult result;
  final String merchantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResultScreen(
      title: 'Retrait',
      headline: 'Retrait effectué',
      subtitle: merchantName.isEmpty
          ? null
          : '${fmtKmf(result.requestedAmount ?? 0)} retirés pour $merchantName.',
      replayed: result.replayed ?? false,
      onDone: () => Navigator.of(context).pop(),
      detail: LipaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            DetailRow(
                label: 'Montant',
                value: fmtKmf(result.requestedAmount ?? 0),
                mono: true),
            if ((result.feeAmount ?? 0) > 0)
              DetailRow(
                  label: 'Frais',
                  value: fmtKmf(result.feeAmount!),
                  mono: true),
            if ((result.commissionAmount ?? 0) > 0)
              DetailRow(
                  label: 'Commission',
                  value: fmtKmf(result.commissionAmount!),
                  mono: true,
                  valueColor: AppColors.brandDeep),
            if (result.transactionId != null)
              DetailRow(
                  label: 'Réf.',
                  value: shortId(result.transactionId!),
                  mono: true,
                  last: true),
          ],
        ),
      ),
    );
  }
}
