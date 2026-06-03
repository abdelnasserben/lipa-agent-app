import '../../core/utils/formatters.dart';
import 'enums.dart';

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
int? _intOrNull(Object? v) => v == null ? null : _int(v);

/// `AgentTransactionResponse` (spec §7.3) — returned by cash-in.
class AgentCashInResult {
  const AgentCashInResult({
    required this.transactionId,
    required this.status,
    required this.requestedAmount,
    required this.feeAmount,
    required this.commissionAmount,
    required this.netAmountToDestination,
    required this.replayed,
    this.completedAt,
  });

  final String transactionId;
  final TransactionStatus status;
  final int requestedAmount;
  final int feeAmount;
  final int commissionAmount;
  final int netAmountToDestination;
  final bool replayed;
  final DateTime? completedAt;

  factory AgentCashInResult.fromJson(Map<String, dynamic> json) =>
      AgentCashInResult(
        transactionId: (json['transactionId'] ?? '') as String,
        status: TransactionStatus.parse(json['status'] as String?),
        requestedAmount: _int(json['requestedAmount']),
        feeAmount: _int(json['feeAmount']),
        commissionAmount: _int(json['commissionAmount']),
        netAmountToDestination: _int(json['netAmountToDestination']),
        replayed: json['replayed'] == true,
        completedAt: tryParseInstant(json['completedAt']),
      );
}

/// `AgentCashOutResponse` (spec §7.3 / §8). [httpStatus] is carried alongside
/// the body because the caller must branch on the HTTP status, not the body:
/// 200 ⇒ executed; 202 ⇒ a control tier paused the operation.
class AgentCashOutResult {
  const AgentCashOutResult({
    required this.httpStatus,
    required this.outcome,
    this.transactionId,
    this.status,
    this.approvalId,
    this.requestedAmount,
    this.matchedThresholdAmount,
    this.feeAmount,
    this.commissionAmount,
    this.netAmountToDestination,
    this.completedAt,
    this.replayed,
  });

  final int httpStatus;
  final CashOutOutcome outcome;
  final String? transactionId;
  final String? status; // TransactionStatus when EXECUTED, ApprovalStatus when PENDING_APPROVAL
  final String? approvalId;
  final int? requestedAmount;
  final int? matchedThresholdAmount;
  final int? feeAmount;
  final int? commissionAmount;
  final int? netAmountToDestination;
  final DateTime? completedAt;
  final bool? replayed;

  bool get isExecuted => outcome == CashOutOutcome.executed;
  bool get needsPin => outcome == CashOutOutcome.pendingPin;
  bool get needsConfirmation => outcome == CashOutOutcome.pendingConfirmation;
  bool get needsApproval => outcome == CashOutOutcome.pendingApproval;

  factory AgentCashOutResult.fromJson(
    Map<String, dynamic> json, {
    required int httpStatus,
  }) =>
      AgentCashOutResult(
        httpStatus: httpStatus,
        outcome: CashOutOutcome.parse(json['outcome'] as String?),
        transactionId: json['transactionId'] as String?,
        status: json['status'] as String?,
        approvalId: json['approvalId'] as String?,
        requestedAmount: _intOrNull(json['requestedAmount']),
        matchedThresholdAmount: _intOrNull(json['matchedThresholdAmount']),
        feeAmount: _intOrNull(json['feeAmount']),
        commissionAmount: _intOrNull(json['commissionAmount']),
        netAmountToDestination: _intOrNull(json['netAmountToDestination']),
        completedAt: tryParseInstant(json['completedAt']),
        replayed: json['replayed'] == true,
      );
}
