import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/enrollment.dart';
import '../../data/repositories/agent_repository.dart';

enum EnrollStep { form, submitting, done, error }

class EnrollState {
  const EnrollState({
    this.step = EnrollStep.form,
    this.result,
    this.errorMessage,
  });

  final EnrollStep step;
  final EnrollCustomerResult? result;
  final String? errorMessage;

  EnrollState copyWith({
    EnrollStep? step,
    EnrollCustomerResult? result,
    String? errorMessage,
    bool clearError = false,
  }) =>
      EnrollState(
        step: step ?? this.step,
        result: result ?? this.result,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// Drives customer enrollment (spec §5.5). On success it exposes the new
/// customer id so the agent can immediately upload KYC documents.
class EnrollController extends StateNotifier<EnrollState> {
  EnrollController(this._ref) : super(const EnrollState());

  final Ref _ref;
  AgentRepository get _repo => _ref.read(agentRepositoryProvider);

  Future<void> submit(EnrollCustomerForm form) async {
    state = state.copyWith(step: EnrollStep.submitting, clearError: true);
    try {
      final res = await _repo.enrollCustomer(form);
      state = state.copyWith(step: EnrollStep.done, result: res);
    } on ApiError catch (e) {
      state = state.copyWith(
          step: EnrollStep.form, errorMessage: frenchMessageForError(e));
    } catch (_) {
      state = state.copyWith(
          step: EnrollStep.form, errorMessage: 'Une erreur est survenue.');
    }
  }
}

final enrollControllerProvider =
    StateNotifierProvider.autoDispose<EnrollController, EnrollState>((ref) {
  return EnrollController(ref);
});
