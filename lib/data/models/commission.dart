import '../../core/utils/formatters.dart';
import 'enums.dart';

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

/// `AgentCommissionResponse` (spec §7.5).
class Commission {
  const Commission({
    required this.id,
    required this.transactionId,
    required this.appliedRuleId,
    required this.amount,
    required this.basisAmount,
    required this.settlementMode,
    required this.status,
    this.paidAt,
    this.paymentTransactionId,
    this.createdAt,
  });

  final String id;
  final String transactionId;
  final String appliedRuleId;
  final int amount;
  final int basisAmount;
  final SettlementMode settlementMode;
  final PayoutStatus status;
  final DateTime? paidAt;
  final String? paymentTransactionId;
  final DateTime? createdAt;

  factory Commission.fromJson(Map<String, dynamic> json) => Commission(
        id: (json['id'] ?? '') as String,
        transactionId: (json['transactionId'] ?? '') as String,
        appliedRuleId: (json['appliedRuleId'] ?? '') as String,
        amount: _int(json['amount']),
        basisAmount: _int(json['basisAmount']),
        settlementMode: SettlementMode.parse(json['settlementMode'] as String?),
        status: PayoutStatus.parse(json['status'] as String?),
        paidAt: tryParseInstant(json['paidAt']),
        paymentTransactionId: json['paymentTransactionId'] as String?,
        createdAt: tryParseInstant(json['createdAt']),
      );
}
