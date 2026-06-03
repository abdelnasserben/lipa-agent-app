import '../../core/auth/token_store.dart';

/// Which branch the agent login response represents (spec §3.1).
enum LoginBranch { session, mfa, pinSetup, unknown }

/// `LoginResponse` (spec §7.1). One DTO covering the three login branches:
/// a full session (`tokens`), an MFA challenge, or a forced PIN setup.
class LoginResponse {
  const LoginResponse({
    required this.mfaRequired,
    this.pinSetupRequired = false,
    this.challengeId,
    this.mfaFactor,
    this.tokens,
    this.pinSetupToken,
    this.pinSetupTokenExpiresAt,
  });

  final bool mfaRequired;
  final bool pinSetupRequired;
  final String? challengeId;
  final String? mfaFactor; // "TOTP"
  final AuthTokens? tokens;
  final String? pinSetupToken;
  final DateTime? pinSetupTokenExpiresAt;

  LoginBranch get branch {
    if (pinSetupRequired && pinSetupToken != null) return LoginBranch.pinSetup;
    if (mfaRequired && challengeId != null) return LoginBranch.mfa;
    if (tokens != null) return LoginBranch.session;
    return LoginBranch.unknown;
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final rawTokens = json['tokens'];
    final rawPinExpiry = json['pinSetupTokenExpiresAt'];
    return LoginResponse(
      mfaRequired: json['mfaRequired'] == true,
      pinSetupRequired: json['pinSetupRequired'] == true,
      challengeId: json['challengeId'] as String?,
      mfaFactor: json['mfaFactor'] as String?,
      tokens: rawTokens is Map<String, dynamic>
          ? AuthTokens.fromJson(rawTokens)
          : null,
      pinSetupToken: json['pinSetupToken'] as String?,
      pinSetupTokenExpiresAt:
          rawPinExpiry is String ? DateTime.tryParse(rawPinExpiry) : null,
    );
  }
}

/// `TotpSetupResponse` (spec §7.1) — returned when enrollment starts.
class TotpSetup {
  const TotpSetup({required this.secret, required this.qrUri});
  final String secret;
  final String qrUri;

  factory TotpSetup.fromJson(Map<String, dynamic> json) => TotpSetup(
        secret: (json['secret'] ?? '') as String,
        qrUri: (json['qrUri'] ?? '') as String,
      );
}
