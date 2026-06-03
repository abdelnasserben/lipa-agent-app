import '../../core/utils/formatters.dart';
import 'enums.dart';

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

/// `AgentPortalTransactionResponse` (spec §7.3) — the wallet-scoped history row
/// and detail view.
class AgentTransaction {
  const AgentTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.sourceWalletId,
    required this.destinationWalletId,
    required this.initiatorType,
    required this.initiatorId,
    required this.requestedAmount,
    required this.feeAmount,
    required this.commissionAmount,
    required this.netAmountToDestination,
    this.cardId,
    this.terminalId,
    this.declineReason,
    this.correlationId,
    this.createdAt,
    this.completedAt,
    this.declinedAt,
    this.agentWalletId,
  });

  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final String sourceWalletId;
  final String destinationWalletId;
  final String initiatorType;
  final String initiatorId;
  final int requestedAmount;
  final int feeAmount;
  final int commissionAmount;
  final int netAmountToDestination;
  final String? cardId;
  final String? terminalId;
  final String? declineReason;
  final String? correlationId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? declinedAt;

  /// The agent's own wallet id, injected so we can derive direction (whether
  /// the agent wallet was debited or credited). Mirrors the customer app's
  /// wallet-scoped direction derivation.
  final String? agentWalletId;

  /// True when the agent wallet received funds (e.g. cash-out, commission).
  bool get incoming =>
      agentWalletId != null && destinationWalletId == agentWalletId;

  /// Signed amount from the agent wallet's perspective (credit +, debit −).
  int get signedAmount => incoming ? requestedAmount : -requestedAmount;

  DateTime? get effectiveAt => completedAt ?? declinedAt ?? createdAt;

  factory AgentTransaction.fromJson(
    Map<String, dynamic> json, {
    String? walletId,
  }) =>
      AgentTransaction(
        id: (json['id'] ?? '') as String,
        type: TransactionType.parse(json['type'] as String?),
        status: TransactionStatus.parse(json['status'] as String?),
        sourceWalletId: (json['sourceWalletId'] ?? '') as String,
        destinationWalletId: (json['destinationWalletId'] ?? '') as String,
        initiatorType: (json['initiatorType'] ?? '') as String,
        initiatorId: (json['initiatorId'] ?? '') as String,
        requestedAmount: _int(json['requestedAmount']),
        feeAmount: _int(json['feeAmount']),
        commissionAmount: _int(json['commissionAmount']),
        netAmountToDestination: _int(json['netAmountToDestination']),
        cardId: json['cardId'] as String?,
        terminalId: json['terminalId'] as String?,
        declineReason: json['declineReason'] as String?,
        correlationId: json['correlationId'] as String?,
        createdAt: tryParseInstant(json['createdAt']),
        completedAt: tryParseInstant(json['completedAt']),
        declinedAt: tryParseInstant(json['declinedAt']),
        agentWalletId: walletId,
      );

  AgentTransaction withWallet(String? walletId) => AgentTransaction(
        id: id,
        type: type,
        status: status,
        sourceWalletId: sourceWalletId,
        destinationWalletId: destinationWalletId,
        initiatorType: initiatorType,
        initiatorId: initiatorId,
        requestedAmount: requestedAmount,
        feeAmount: feeAmount,
        commissionAmount: commissionAmount,
        netAmountToDestination: netAmountToDestination,
        cardId: cardId,
        terminalId: terminalId,
        declineReason: declineReason,
        correlationId: correlationId,
        createdAt: createdAt,
        completedAt: completedAt,
        declinedAt: declinedAt,
        agentWalletId: walletId,
      );
}

/// `AgentStatementEntryResponse` (spec §7.3) — a wallet ledger entry.
class StatementEntry {
  const StatementEntry({
    required this.id,
    required this.transactionId,
    required this.entryType,
    required this.amount,
    required this.runningBalance,
    required this.description,
    this.postedAt,
    this.globalSequence,
  });

  final String id;
  final String transactionId;
  final EntryType entryType;
  final int amount;
  final int runningBalance;

  /// Internal ledger string from the backend that *leads* with the raw
  /// TX-type token followed by technical detail, e.g.
  /// `SERVICE_PAYMENT debit(...)`, `P2P_TRANSFER credit(r...)`. Localize the
  /// leading token via [TransactionType.frLabel] (cf. Lipa statement
  /// description convention; mirrors the customer app).
  final String description;
  final DateTime? postedAt;
  final int? globalSequence;

  /// French label derived from the *leading* TX-type token of [description]
  /// (the rest of the string is technical detail we drop). Free text with no
  /// recognizable leading token passes through; an empty string falls back to
  /// the generic label.
  String get descriptionFr {
    final raw = description.trim();
    final t = _leadingType(raw);
    if (t != null && t != TransactionType.unknown) return t.frLabel;
    return raw.isEmpty ? TransactionType.unknown.frLabel : raw;
  }

  /// Parses the leading SCREAMING_SNAKE token (the type) from a ledger
  /// description. Returns null when the string doesn't start with such a token.
  static TransactionType? _leadingType(String s) {
    final m = RegExp(r'^([A-Z][A-Z0-9_]*)').firstMatch(s);
    if (m == null) return null;
    return TransactionType.parse(m.group(1));
  }

  /// Signed amount from the entry type.
  int get signedAmount => entryType.isCredit ? amount : -amount;

  factory StatementEntry.fromJson(Map<String, dynamic> json) => StatementEntry(
        id: (json['id'] ?? '') as String,
        transactionId: (json['transactionId'] ?? '') as String,
        entryType: EntryType.parse(json['entryType'] as String?),
        amount: _int(json['amount']),
        runningBalance: _int(json['runningBalance']),
        description: (json['description'] ?? '') as String,
        postedAt: tryParseInstant(json['postedAt']),
        globalSequence:
            json['globalSequence'] is num ? _int(json['globalSequence']) : null,
      );
}
