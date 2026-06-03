import '../../core/utils/formatters.dart';
import 'enums.dart';

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
int? _intOrNull(Object? v) => v == null ? null : _int(v);

/// `AgentProfileResponse` (spec §7.2). Drives the dashboard, capability gating,
/// and the profile screen.
class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.externalRef,
    required this.fullName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.kycLevel,
    required this.status,
    required this.canSellCards,
    required this.canDoCashIn,
    required this.canDoCashOut,
    required this.floatAlertThreshold,
    this.zone,
    this.walletId,
    this.limitProfileId,
    this.contractRef,
    this.createdAt,
  });

  final String id;
  final String externalRef;
  final String fullName;
  final String phoneCountryCode;
  final String phoneNumber;
  final KycLevel kycLevel;
  final AgentStatus status;
  final bool canSellCards;
  final bool canDoCashIn;
  final bool canDoCashOut;
  final int floatAlertThreshold;
  final String? zone;
  final String? walletId;
  final String? limitProfileId;
  final String? contractRef;
  final DateTime? createdAt;

  String get phonePretty => fmtPhone(phoneCountryCode, phoneNumber);

  /// Capability gating per spec §10.3 / §11.3 — hide actions the agent can't do.
  bool get hasAnyCashOps => canDoCashIn || canDoCashOut;

  factory AgentProfile.fromJson(Map<String, dynamic> json) => AgentProfile(
        id: (json['id'] ?? '') as String,
        externalRef: (json['externalRef'] ?? '') as String,
        fullName: (json['fullName'] ?? '') as String,
        phoneCountryCode: (json['phoneCountryCode'] ?? '') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        kycLevel: KycLevel.parse(json['kycLevel'] as String?),
        status: AgentStatus.parse(json['status'] as String?),
        canSellCards: json['canSellCards'] == true,
        canDoCashIn: json['canDoCashIn'] == true,
        canDoCashOut: json['canDoCashOut'] == true,
        floatAlertThreshold: _int(json['floatAlertThreshold']),
        zone: json['zone'] as String?,
        walletId: json['walletId'] as String?,
        limitProfileId: json['limitProfileId'] as String?,
        contractRef: json['contractRef'] as String?,
        createdAt: tryParseInstant(json['createdAt']),
      );
}

/// `AgentBalanceResponse` (spec §7.2).
class AgentBalance {
  const AgentBalance({
    required this.walletId,
    required this.availableBalance,
    required this.frozenBalance,
    required this.walletStatus,
    this.updatedAt,
  });

  final String walletId;
  final int availableBalance;
  final int frozenBalance;
  final WalletStatus walletStatus;
  final DateTime? updatedAt;

  factory AgentBalance.fromJson(Map<String, dynamic> json) => AgentBalance(
        walletId: (json['walletId'] ?? '') as String,
        availableBalance: _int(json['availableBalance']),
        frozenBalance: _int(json['frozenBalance']),
        walletStatus: WalletStatus.parse(json['walletStatus'] as String?),
        updatedAt: tryParseInstant(json['updatedAt']),
      );
}

/// `AgentLimitsResponse` (spec §7.2). Null fields mean "not configured".
class AgentLimits {
  const AgentLimits({
    required this.limitProfileId,
    required this.profileName,
    required this.requiredKycLevel,
    this.maxTransactionAmount,
    this.minTransactionAmount,
    this.maxDailyAmount,
    this.maxWeeklyAmount,
    this.maxMonthlyAmount,
    this.maxDailyTransactionCount,
    this.maxMonthlyTransactionCount,
  });

  final String limitProfileId;
  final String profileName;
  final KycLevel requiredKycLevel;
  final int? maxTransactionAmount;
  final int? minTransactionAmount;
  final int? maxDailyAmount;
  final int? maxWeeklyAmount;
  final int? maxMonthlyAmount;
  final int? maxDailyTransactionCount;
  final int? maxMonthlyTransactionCount;

  factory AgentLimits.fromJson(Map<String, dynamic> json) => AgentLimits(
        limitProfileId: (json['limitProfileId'] ?? '') as String,
        profileName: (json['profileName'] ?? '') as String,
        requiredKycLevel: KycLevel.parse(json['requiredKycLevel'] as String?),
        maxTransactionAmount: _intOrNull(json['maxTransactionAmount']),
        minTransactionAmount: _intOrNull(json['minTransactionAmount']),
        maxDailyAmount: _intOrNull(json['maxDailyAmount']),
        maxWeeklyAmount: _intOrNull(json['maxWeeklyAmount']),
        maxMonthlyAmount: _intOrNull(json['maxMonthlyAmount']),
        maxDailyTransactionCount: _intOrNull(json['maxDailyTransactionCount']),
        maxMonthlyTransactionCount:
            _intOrNull(json['maxMonthlyTransactionCount']),
      );
}

/// `AgentDailySummaryResponse` (spec §7.2).
class AgentDailySummary {
  const AgentDailySummary({
    required this.agentId,
    required this.totalCompletedAmountToday,
    required this.totalCompletedCountToday,
    required this.commissionEarnedToday,
    required this.currentBalance,
    required this.floatAlertThreshold,
    required this.belowFloatAlert,
    this.periodStart,
    this.periodEnd,
  });

  final String agentId;
  final int totalCompletedAmountToday;
  final int totalCompletedCountToday;
  final int commissionEarnedToday;
  final int currentBalance;
  final int floatAlertThreshold;
  final bool belowFloatAlert;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory AgentDailySummary.fromJson(Map<String, dynamic> json) =>
      AgentDailySummary(
        agentId: (json['agentId'] ?? '') as String,
        totalCompletedAmountToday: _int(json['totalCompletedAmountToday']),
        totalCompletedCountToday: _int(json['totalCompletedCountToday']),
        commissionEarnedToday: _int(json['commissionEarnedToday']),
        currentBalance: _int(json['currentBalance']),
        floatAlertThreshold: _int(json['floatAlertThreshold']),
        belowFloatAlert: json['belowFloatAlert'] == true,
        periodStart: tryParseInstant(json['periodStart']),
        periodEnd: tryParseInstant(json['periodEnd']),
      );
}
