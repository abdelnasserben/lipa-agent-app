import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/cash_result.dart';
import '../../data/models/lookup.dart';
import '../../data/repositories/agent_repository.dart';
import '../agent/agent_providers.dart';

/// Where the cash-out flow currently is.
enum CashOutStep {
  lookup, // resolving the merchant by phone
  amount, // entering the amount
  needsConfirmation, // 202 PENDING_CONFIRMATION — ask to acknowledge
  needsPin, // 202 PENDING_PIN — merchant types their PIN
  approval, // 202 PENDING_APPROVAL — terminal, agent can't act
  done, // 200 EXECUTED
}

class CashOutState {
  const CashOutState({
    this.step = CashOutStep.lookup,
    this.looking = false,
    this.submitting = false,
    this.merchant,
    this.amount = 0,
    this.result,
    this.errorMessage,
    this.pinError,
  });

  final CashOutStep step;
  final bool looking;
  final bool submitting;
  final MerchantLookup? merchant;
  final int amount;
  final AgentCashOutResult? result;
  final String? errorMessage;

  /// Inline error shown inside the PIN sheet (wrong merchant PIN / locked).
  final String? pinError;

  CashOutState copyWith({
    CashOutStep? step,
    bool? looking,
    bool? submitting,
    MerchantLookup? merchant,
    int? amount,
    AgentCashOutResult? result,
    String? errorMessage,
    String? pinError,
    bool clearError = false,
    bool clearPinError = false,
  }) =>
      CashOutState(
        step: step ?? this.step,
        looking: looking ?? this.looking,
        submitting: submitting ?? this.submitting,
        merchant: merchant ?? this.merchant,
        amount: amount ?? this.amount,
        result: result ?? this.result,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        pinError: clearPinError ? null : (pinError ?? this.pinError),
      );
}

/// Drives the cash-out control-tier loop (spec §8). A single intent reuses one
/// idempotency key across the confirmation / PIN resubmits (spec §11.2). Branch
/// on the HTTP status carried by the result, not the body.
class CashOutController extends StateNotifier<CashOutState> {
  CashOutController(this._ref) : super(const CashOutState());

  final Ref _ref;
  static const _countryCode = '269';
  final String _idempotencyKey = newIdempotencyKey();

  bool _confirmationAcknowledged = false;

  AgentRepository get _repo => _ref.read(agentRepositoryProvider);

  Future<void> lookup(String phoneNumber) async {
    state = state.copyWith(looking: true, clearError: true);
    try {
      final m = await _repo.lookupMerchant(
        phoneCountryCode: _countryCode,
        phoneNumber: phoneNumber.replaceAll(RegExp(r'\D'), ''),
      );
      state =
          state.copyWith(looking: false, merchant: m, step: CashOutStep.amount);
    } on ApiError catch (e) {
      state = state.copyWith(
          looking: false, errorMessage: frenchMessageForError(e));
    } catch (_) {
      state = state.copyWith(
          looking: false, errorMessage: 'Une erreur est survenue.');
    }
  }

  void setAmount(int amount) => state = state.copyWith(amount: amount);

  void backToLookup() =>
      state = state.copyWith(step: CashOutStep.lookup, clearError: true);

  /// Return to the amount step (e.g. the merchant-PIN sheet was dismissed
  /// before completion), keeping the resolved merchant and entered amount.
  void backToLookupAmount() => state = state.copyWith(
      step: CashOutStep.amount, clearError: true, clearPinError: true);

  /// First submit (and the resubmit after the confirmation prompt).
  Future<void> submit() => _send();

  /// Resubmit after the agent acknowledges the confirmation prompt.
  Future<void> acknowledgeConfirmation() {
    _confirmationAcknowledged = true;
    return _send();
  }

  /// Resubmit with the merchant PIN typed on the device.
  Future<void> submitPin(String pin) => _send(pin: pin);

  Future<void> _send({String? pin}) async {
    final merchant = state.merchant;
    if (merchant == null || state.amount <= 0) return;
    state = state.copyWith(
        submitting: true, clearError: true, clearPinError: true);
    try {
      final res = await _repo.cashOut(
        idempotencyKey: _idempotencyKey,
        merchantId: merchant.merchantId,
        amount: state.amount,
        merchantPin: pin,
        confirmationAcknowledged: _confirmationAcknowledged ? true : null,
      );
      if (res.isExecuted) {
        _ref.invalidate(balanceProvider);
        _ref.invalidate(dailySummaryProvider);
        _ref.invalidate(transactionsProvider);
        _ref.invalidate(statementsProvider);
        state = state.copyWith(
            submitting: false, step: CashOutStep.done, result: res);
      } else if (res.needsConfirmation) {
        state = state.copyWith(
            submitting: false,
            step: CashOutStep.needsConfirmation,
            result: res);
      } else if (res.needsPin) {
        state = state.copyWith(
            submitting: false, step: CashOutStep.needsPin, result: res);
      } else if (res.needsApproval) {
        state = state.copyWith(
            submitting: false, step: CashOutStep.approval, result: res);
      } else {
        state = state.copyWith(
            submitting: false,
            step: CashOutStep.amount,
            errorMessage: 'Réponse inattendue du serveur.');
      }
    } on ApiError catch (e) {
      // A wrong / locked merchant PIN must surface inside the PIN sheet so the
      // agent stays on the PIN step and can retry (spec §8).
      if (state.step == CashOutStep.needsPin &&
          (e.code == 'AUTH_PIN_INVALID' || e.code == 'AUTH_PIN_LOCKED')) {
        state = state.copyWith(
            submitting: false, pinError: frenchMessageForError(e));
      } else {
        state = state.copyWith(
            submitting: false,
            step: CashOutStep.amount,
            errorMessage: frenchMessageForError(e));
      }
    } catch (_) {
      state = state.copyWith(
          submitting: false,
          step: CashOutStep.amount,
          errorMessage: 'Une erreur est survenue.');
    }
  }
}

final cashOutControllerProvider =
    StateNotifierProvider.autoDispose<CashOutController, CashOutState>((ref) {
  return CashOutController(ref);
});
