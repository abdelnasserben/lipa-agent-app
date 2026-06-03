import '../../core/utils/formatters.dart';
import 'enums.dart';

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
int? _intOrNull(Object? v) => v == null ? null : _int(v);

/// `AgentCardStockView` (spec §7.5) — one card in the agent's assigned stock.
class CardStockItem {
  const CardStockItem({
    required this.id,
    required this.nfcUid,
    required this.internalCardNumber,
    required this.batchRef,
    required this.status,
    this.producedAt,
    this.assignedAt,
  });

  final String id;
  final String nfcUid;
  final String internalCardNumber;
  final String batchRef;
  final CardStockStatus status;
  final DateTime? producedAt;
  final DateTime? assignedAt;

  factory CardStockItem.fromJson(Map<String, dynamic> json) => CardStockItem(
        id: (json['id'] ?? '') as String,
        nfcUid: (json['nfcUid'] ?? '') as String,
        internalCardNumber: (json['internalCardNumber'] ?? '') as String,
        batchRef: (json['batchRef'] ?? '') as String,
        status: CardStockStatus.parse(json['status'] as String?),
        producedAt: tryParseInstant(json['producedAt']),
        assignedAt: tryParseInstant(json['assignedAt']),
      );
}

/// `AgentCardSaleResponse` (spec §7.5).
class CardSaleResult {
  const CardSaleResult({
    required this.transactionId,
    required this.status,
    required this.cardId,
    required this.customerId,
    required this.cardPrice,
    required this.commissionAmount,
    required this.replayed,
    this.completedAt,
  });

  final String transactionId;
  final TransactionStatus status;
  final String cardId;
  final String customerId;

  /// Authoritative price actually debited — always display this, not the sent
  /// value (spec §6.5 config-driven pricing note).
  final int cardPrice;
  final int commissionAmount;
  final bool replayed;
  final DateTime? completedAt;

  factory CardSaleResult.fromJson(Map<String, dynamic> json) => CardSaleResult(
        transactionId: (json['transactionId'] ?? '') as String,
        status: TransactionStatus.parse(json['status'] as String?),
        cardId: (json['cardId'] ?? '') as String,
        customerId: (json['customerId'] ?? '') as String,
        cardPrice: _int(json['cardPrice']),
        commissionAmount: _int(json['commissionAmount']),
        replayed: json['replayed'] == true,
        completedAt: tryParseInstant(json['completedAt']),
      );
}

/// `AgentCardReplacementResponse` (spec §7.5).
class CardReplacementResult {
  const CardReplacementResult({
    required this.newCardId,
    required this.oldCardId,
    required this.customerId,
    required this.replayed,
    this.transactionId,
    this.status,
    this.replacementFee,
    this.commissionAmount,
    this.completedAt,
  });

  final String newCardId;
  final String oldCardId;
  final String customerId;
  final bool replayed;
  final String? transactionId;
  final TransactionStatus? status;

  /// Authoritative fee actually charged — always display this (spec §6.5).
  final int? replacementFee;
  final int? commissionAmount;
  final DateTime? completedAt;

  factory CardReplacementResult.fromJson(Map<String, dynamic> json) =>
      CardReplacementResult(
        newCardId: (json['newCardId'] ?? '') as String,
        oldCardId: (json['oldCardId'] ?? '') as String,
        customerId: (json['customerId'] ?? '') as String,
        replayed: json['replayed'] == true,
        transactionId: json['transactionId'] as String?,
        status: json['status'] == null
            ? null
            : TransactionStatus.parse(json['status'] as String?),
        replacementFee: _intOrNull(json['replacementFee']),
        commissionAmount: _intOrNull(json['commissionAmount']),
        completedAt: tryParseInstant(json['completedAt']),
      );
}
