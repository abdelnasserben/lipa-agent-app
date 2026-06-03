import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The token bundle returned by agent login / refresh (spec §7.1).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  bool get isAccessExpired => DateTime.now().isAfter(accessTokenExpiresAt);

  /// Should we refresh now, given a lead time before expiry?
  bool shouldRefresh(Duration lead) =>
      DateTime.now().isAfter(accessTokenExpiresAt.subtract(lead));

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        accessTokenExpiresAt: DateTime.parse(
          json['accessTokenExpiresAt'] as String,
        ),
        refreshToken: json['refreshToken'] as String,
        refreshTokenExpiresAt: DateTime.parse(
          json['refreshTokenExpiresAt'] as String,
        ),
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
        'refreshToken': refreshToken,
        'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
      };
}

/// Persists tokens in the platform secure enclave (Keychain / Keystore).
/// Never write tokens to plain prefs or logs.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'lipa.agent.tokens';

  AuthTokens? _cache;

  AuthTokens? get current => _cache;

  Future<AuthTokens?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      _cache = AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
    return _cache;
  }

  Future<void> save(AuthTokens tokens) async {
    _cache = tokens;
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _key);
  }
}
