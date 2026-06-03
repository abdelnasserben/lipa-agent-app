import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../security/security_controller.dart';

/// High-level session state that drives the root router (logged in vs auth).
enum SessionStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({required this.status, this.expiredNotice = false});

  final SessionStatus status;

  /// True right after an involuntary logout (token expiry) so the auth screen
  /// can show the "session expired" variant.
  final bool expiredNotice;

  SessionState copyWith({SessionStatus? status, bool? expiredNotice}) =>
      SessionState(
        status: status ?? this.status,
        expiredNotice: expiredNotice ?? this.expiredNotice,
      );
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref)
      : super(const SessionState(status: SessionStatus.unknown)) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    // Wire the API client's involuntary-logout signal back to us.
    _ref.read(apiClientProvider).onSessionExpired = _onSessionExpired;
    final tokenStore = _ref.read(tokenStoreProvider);
    final tokens = await tokenStore.load();
    final hasValidRefresh =
        tokens != null && DateTime.now().isBefore(tokens.refreshTokenExpiresAt);
    state = SessionState(
      status: hasValidRefresh
          ? SessionStatus.authenticated
          : SessionStatus.unauthenticated,
    );
  }

  /// Called by the auth flow after a successful login / MFA / token issue.
  void markAuthenticated() {
    state = const SessionState(status: SessionStatus.authenticated);
  }

  void _onSessionExpired() {
    if (state.status == SessionStatus.authenticated) {
      state = const SessionState(
          status: SessionStatus.unauthenticated, expiredNotice: true);
      _resetUserScopedState();
    }
  }

  Future<void> logout() async {
    try {
      await _ref.read(authRepositoryProvider).logout();
    } finally {
      state = const SessionState(status: SessionStatus.unauthenticated);
      _resetUserScopedState();
    }
  }

  /// Tears down per-user state that would otherwise leak across accounts.
  ///
  /// [agentRepositoryProvider] is a long-lived singleton that caches the
  /// signed-in agent's `walletId` (used to derive transaction direction); we
  /// rebuild it so the next agent starts clean. The `autoDispose` data
  /// providers unmount with the shell at logout and start fresh on re-login.
  /// (Cf. the Lipa customer app's user-scoped state reset.)
  void _resetUserScopedState() {
    _ref.invalidate(agentRepositoryProvider);
    // Session-scoped TOTP flag must not leak to the next agent.
    _ref.read(totpEnrolledProvider.notifier).state = false;
  }

  void clearExpiredNotice() {
    if (state.expiredNotice) {
      state = state.copyWith(expiredNotice: false);
    }
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});
