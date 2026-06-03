import '../../core/auth/token_store.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_envelopes.dart';
import '../models/login_response.dart';

/// Agent auth surface (spec §5.1). Implementation: [ApiAuthRepository].
abstract class AuthRepository {
  Future<LoginResponse> login({
    required String phoneCountryCode,
    required String phoneNumber,
    required String pin,
  });

  Future<AuthTokens> verifyMfa({
    required String challengeId,
    required String code,
  });

  /// Sets the initial PIN using the single-use PIN_SETUP token (spec §3.6).
  Future<void> setupPin({
    required String pinSetupToken,
    required String pin,
  });

  /// Rotates the PIN for an already-logged-in agent (requires currentPin).
  Future<void> changePin({required String currentPin, required String newPin});

  /// Forgotten-PIN self-service, gated by TOTP (spec §3.6).
  Future<void> resetPinViaTotp({
    required String phoneCountryCode,
    required String phoneNumber,
    required String totpCode,
    required String newPin,
  });

  /// Starts TOTP enrollment — returns the secret + `otpauth://` QR URI (§3.7).
  Future<TotpSetup> startTotpSetup();

  /// Confirms the pending TOTP secret with the first 6-digit code.
  Future<void> confirmTotp(String code);

  /// Revokes TOTP; steps up with a current 6-digit code.
  Future<void> revokeTotp(String code);

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._tokenStore);

  final ApiClient _api;
  final TokenStore _tokenStore;

  static const _base = '/api/v1/auth/agent';

  @override
  Future<LoginResponse> login({
    required String phoneCountryCode,
    required String phoneNumber,
    required String pin,
  }) async {
    final res = await _api.post(
      '$_base/login',
      skipAuth: true,
      body: {
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
        'pin': pin,
      },
    );
    final data = _data(res.data);
    final parsed = LoginResponse.fromJson(data);
    if (parsed.branch == LoginBranch.session && parsed.tokens != null) {
      await _tokenStore.save(parsed.tokens!);
    }
    return parsed;
  }

  @override
  Future<AuthTokens> verifyMfa({
    required String challengeId,
    required String code,
  }) async {
    final res = await _api.post(
      '$_base/login/verify-mfa',
      skipAuth: true,
      body: {'challengeId': challengeId, 'code': code},
    );
    final data = _data(res.data);
    final tokens = AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>);
    await _tokenStore.save(tokens);
    return tokens;
  }

  @override
  Future<void> setupPin({
    required String pinSetupToken,
    required String pin,
  }) async {
    await _api.post(
      '$_base/auth-pin/setup',
      bearer: pinSetupToken,
      body: {'pin': pin},
    );
  }

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    await _api.put(
      '$_base/auth-pin',
      body: {'currentPin': currentPin, 'newPin': newPin},
    );
  }

  @override
  Future<void> resetPinViaTotp({
    required String phoneCountryCode,
    required String phoneNumber,
    required String totpCode,
    required String newPin,
  }) async {
    await _api.post(
      '$_base/auth-pin/reset',
      skipAuth: true,
      body: {
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
        'totpCode': totpCode,
        'newPin': newPin,
      },
    );
  }

  @override
  Future<TotpSetup> startTotpSetup() async {
    final res = await _api.post('$_base/totp-setup');
    return unwrapData(
        res.data, (d) => TotpSetup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<void> confirmTotp(String code) async {
    await _api.post('$_base/totp-confirm', body: {'code': code});
  }

  @override
  Future<void> revokeTotp(String code) async {
    await _api.delete('$_base/totp-setup', body: {'code': code});
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('$_base/logout');
    } finally {
      await _tokenStore.clear();
    }
  }

  Map<String, dynamic> _data(Object? body) {
    if (body is Map<String, dynamic> && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    return body is Map<String, dynamic> ? body : const {};
  }
}
