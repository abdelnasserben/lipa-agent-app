import '../../core/utils/formatters.dart';
import 'enums.dart';

/// `CustomerLookupResponse` (spec §7.4) — minimal projection for pre-transaction
/// confirmation before a cash-in.
class CustomerLookup {
  const CustomerLookup({
    required this.customerId,
    required this.fullName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.status,
    required this.kycLevel,
  });

  final String customerId;
  final String fullName;
  final String phoneCountryCode;
  final String phoneNumber;
  final CustomerStatus status;
  final KycLevel kycLevel;

  String get phonePretty => fmtPhone(phoneCountryCode, phoneNumber);

  factory CustomerLookup.fromJson(Map<String, dynamic> json) => CustomerLookup(
        customerId: (json['customerId'] ?? '') as String,
        fullName: (json['fullName'] ?? '') as String,
        phoneCountryCode: (json['phoneCountryCode'] ?? '') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        status: CustomerStatus.parse(json['status'] as String?),
        kycLevel: KycLevel.parse(json['kycLevel'] as String?),
      );
}

/// `MerchantLookupResponse` (spec §7.4) — resolves `merchantId` for cash-out.
class MerchantLookup {
  const MerchantLookup({
    required this.merchantId,
    required this.externalRef,
    required this.businessName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.status,
    required this.kycLevel,
    required this.canCashOut,
  });

  final String merchantId;
  final String externalRef;
  final String businessName;
  final String phoneCountryCode;
  final String phoneNumber;
  final MerchantStatus status;
  final KycLevel kycLevel;
  final bool canCashOut;

  String get phonePretty => fmtPhone(phoneCountryCode, phoneNumber);

  factory MerchantLookup.fromJson(Map<String, dynamic> json) => MerchantLookup(
        merchantId: (json['merchantId'] ?? '') as String,
        externalRef: (json['externalRef'] ?? '') as String,
        businessName: (json['businessName'] ?? '') as String,
        phoneCountryCode: (json['phoneCountryCode'] ?? '') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        status: MerchantStatus.parse(json['status'] as String?),
        kycLevel: KycLevel.parse(json['kycLevel'] as String?),
        canCashOut: json['canCashOut'] == true,
      );
}

/// `CardLookupResponse` (spec §7.4) — minimal card projection by NFC UID.
/// Never carries PIN or full card number. Reused as the confirmation payload
/// for report-lost / report-stolen.
class CardLookup {
  const CardLookup({
    required this.cardId,
    required this.nfcUid,
    required this.cardType,
    required this.status,
    this.internalCardLast4,
    this.maskedInternalCardNumber,
    this.customerId,
    this.customerFullName,
    this.customerPhoneMasked,
    this.expiresAt,
  });

  final String cardId;
  final String nfcUid;
  final CardType cardType;
  final CardStatus status;
  final String? internalCardLast4;
  final String? maskedInternalCardNumber;
  final String? customerId;
  final String? customerFullName;
  final String? customerPhoneMasked;
  final DateTime? expiresAt;

  bool get isLinked => customerId != null && customerId!.isNotEmpty;

  factory CardLookup.fromJson(Map<String, dynamic> json) => CardLookup(
        cardId: (json['cardId'] ?? '') as String,
        nfcUid: (json['nfcUid'] ?? '') as String,
        cardType: CardType.parse(json['cardType'] as String?),
        status: CardStatus.parse(json['status'] as String?),
        internalCardLast4: json['internalCardLast4'] as String?,
        maskedInternalCardNumber: json['maskedInternalCardNumber'] as String?,
        customerId: json['customerId'] as String?,
        customerFullName: json['customerFullName'] as String?,
        customerPhoneMasked: json['customerPhoneMasked'] as String?,
        expiresAt: tryParseInstant(json['expiresAt']),
      );
}
