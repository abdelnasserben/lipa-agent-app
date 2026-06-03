/// Backend error code → typed handling. Mirrors the codes listed in the
/// Agent spec §5 (per-endpoint "Primary errors").
///
/// We keep the raw `code` string so unknown/future codes never crash the app.
class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.code,
    this.message,
    this.details = const [],
    this.correlationId,
  });

  final int statusCode;
  final String code;
  final String? message;
  final List<String> details;
  final String? correlationId;

  /// Parses both the wrapped `{ "error": {...} }` envelope (controller /
  /// validation / 429) and the raw `ApiError` body that Spring Security emits
  /// for 401/403. See spec §2.3.
  factory ApiError.fromResponse(int statusCode, Object? body) {
    Map<String, dynamic>? err;
    if (body is Map<String, dynamic>) {
      final wrapped = body['error'];
      if (wrapped is Map<String, dynamic>) {
        err = wrapped;
      } else if (body.containsKey('code')) {
        err = body; // raw ApiError (security filter)
      }
    }
    final details = <String>[];
    final rawDetails = err?['details'];
    if (rawDetails is List) {
      details.addAll(rawDetails.map((e) => e.toString()));
    }
    return ApiError(
      statusCode: statusCode,
      code: (err?['code'] as String?) ?? _fallbackCode(statusCode),
      message: err?['message'] as String?,
      details: details,
      correlationId: err?['correlationId'] as String?,
    );
  }

  static String _fallbackCode(int status) {
    switch (status) {
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 429:
        return 'TERMINAL_RATE_LIMIT';
      default:
        return 'UNKNOWN_ERROR';
    }
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  /// True for the 422 codes that mean the actor's account/wallet is unusable
  /// and not self-recoverable (spec §3.1 / §5.4).
  bool get isAccountBlocked => const {
        'ACTOR_PENDING_KYC',
        'ACTOR_SUSPENDED',
        'ACTOR_CLOSED',
        'AGENT_NOT_FOUND',
        'WALLET_FROZEN',
        'WALLET_SUSPENDED',
        'WALLET_CLOSED',
      }.contains(code);

  /// A network/transport failure with no HTTP response (timeout, no route).
  factory ApiError.network([String? message]) => ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: message ?? 'Connexion impossible. Vérifiez votre réseau.',
      );

  @override
  String toString() => 'ApiError($statusCode $code: ${message ?? ''})';
}

/// Maps backend error codes to user-facing French copy, aligned with the Agent
/// spec. Falls back to a generic message for unknown codes — never leaks raw
/// codes to the operator.
String frenchMessageForError(ApiError e) {
  switch (e.code) {
    // ── Session / auth ─────────────────────────────────────────────────────
    case 'INVALID_CREDENTIALS':
      return 'Numéro ou PIN incorrect.';
    case 'AUTH_PIN_INVALID':
      return 'PIN incorrect. Réessayez.';
    case 'AUTH_PIN_LOCKED':
      return 'PIN bloqué. Réessayez dans 15 minutes.';
    case 'AUTH_PIN_FORMAT':
      return 'Le PIN doit comporter 4 à 8 chiffres.';
    case 'AUTH_PIN_ALREADY_SET':
      return 'Un PIN est déjà défini pour ce compte.';
    case 'AUTH_PIN_NOT_SET':
      return 'Aucun PIN n’est défini pour ce compte.';
    case 'AUTH_PIN_RESET_TOTP_REQUIRED':
      return 'Activez le TOTP ou contactez le back-office pour réinitialiser votre PIN.';
    case 'AUTH_INVALID_TOKEN':
      return 'Lien expiré. Recommencez la connexion.';
    case 'AUTH_MFA_INVALID':
    case 'MFA_INVALID':
      return 'Code de vérification invalide.';
    case 'REFRESH_TOKEN_INVALID':
      return 'Votre session a expiré. Reconnectez-vous.';
    case 'TERMINAL_RATE_LIMIT':
      return 'Trop de tentatives. Réessayez dans un instant.';
    case 'ACTOR_PENDING_KYC':
      return 'Votre compte agent est en cours de vérification.';
    case 'ACTOR_SUSPENDED':
    case 'ACTOR_CLOSED':
      return 'Compte agent indisponible. Contactez le back-office.';

    // ── Financial / business ───────────────────────────────────────────────
    case 'INSUFFICIENT_BALANCE':
      return 'Float insuffisant pour cette opération.';
    case 'LIMIT_EXCEEDED':
      return 'Plafond dépassé. Consultez vos plafonds.';
    case 'WALLET_FROZEN':
    case 'WALLET_SUSPENDED':
    case 'WALLET_CLOSED':
      return 'Portefeuille indisponible. Contactez le back-office.';
    case 'CONFIG_LIMIT_PROFILE_NOT_FOUND':
    case 'CONFIG_RULE_INACTIVE':
      return 'Service temporairement indisponible. Réessayez plus tard.';
    case 'APPROVAL_REQUIRED':
      return 'Montant soumis à approbation du back-office.';
    case 'CASH_OUT_NOT_ALLOWED':
      return 'Ce marchand ne peut pas effectuer de retrait.';
    case 'DUPLICATE_IDEMPOTENCY_KEY':
      return 'Opération déjà en cours de traitement.';

    // ── Lookup / not found ─────────────────────────────────────────────────
    case 'CUSTOMER_NOT_FOUND':
      return 'Ce numéro ne correspond à aucun client Lipa.';
    case 'MERCHANT_NOT_FOUND':
      return 'Ce numéro ne correspond à aucun marchand Lipa.';
    case 'CARD_NOT_FOUND':
      return 'Carte introuvable pour cet UID.';
    case 'TRANSACTION_NOT_FOUND':
      return 'Transaction introuvable.';
    case 'ACTOR_NOT_FOUND':
    case 'WALLET_NOT_FOUND':
      return 'Introuvable.';

    // ── Enrollment / KYC ───────────────────────────────────────────────────
    case 'PHONE_ALREADY_IN_USE':
      return 'Ce numéro de téléphone est déjà utilisé.';
    case 'NATIONAL_ID_ALREADY_IN_USE':
      return 'Ce numéro de pièce d’identité est déjà utilisé.';

    // ── Cards / stock ──────────────────────────────────────────────────────
    case 'CARD_STOCK_NOT_FOUND':
      return 'Stock de cartes introuvable.';
    case 'CARD_STOCK_WRONG_STATUS':
      return 'Cette carte n’est pas disponible à la vente.';
    case 'CARD_STOCK_NOT_ASSIGNED_TO_AGENT':
      return 'Cette carte ne vous est pas attribuée.';
    case 'CARD_NOT_ACTIVE':
      return 'La carte à remplacer n’est pas active.';

    // ── Validation / transport ─────────────────────────────────────────────
    case 'VALIDATION_FIELD_REQUIRED':
    case 'VALIDATION_ERROR':
    case 'VALIDATION_INVALID_FORMAT':
      return 'Données invalides. Vérifiez les champs.';
    case 'NETWORK_ERROR':
      return e.message ?? 'Connexion impossible. Vérifiez votre réseau.';
    default:
      return e.message ?? 'Une erreur est survenue. Réessayez.';
  }
}
