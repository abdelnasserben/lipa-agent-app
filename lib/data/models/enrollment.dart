import '../../core/utils/formatters.dart';
import 'enums.dart';

/// `EnrollCustomerResponse` (spec §7.4).
class EnrollCustomerResult {
  const EnrollCustomerResult({
    required this.customerId,
    required this.externalRef,
    required this.walletId,
  });

  final String customerId;
  final String externalRef;
  final String walletId;

  factory EnrollCustomerResult.fromJson(Map<String, dynamic> json) =>
      EnrollCustomerResult(
        customerId: (json['customerId'] ?? '') as String,
        externalRef: (json['externalRef'] ?? '') as String,
        walletId: (json['walletId'] ?? '') as String,
      );
}

/// `KycDocumentResponse` (spec §7.4).
class KycDocument {
  const KycDocument({
    required this.id,
    required this.documentType,
    required this.status,
    required this.contentHash,
    this.uploadedAt,
  });

  final String id;
  final KycDocumentType documentType;
  final KycDocumentStatus status;
  final String contentHash;
  final DateTime? uploadedAt;

  factory KycDocument.fromJson(Map<String, dynamic> json) => KycDocument(
        id: (json['id'] ?? '') as String,
        documentType: KycDocumentType.parse(json['documentType'] as String?),
        status: KycDocumentStatus.parse(json['status'] as String?),
        contentHash: (json['contentHash'] ?? '') as String,
        uploadedAt: tryParseInstant(json['uploadedAt']),
      );
}

/// Local form payload for `EnrollCustomerRequest` (spec §6.3). Validated in the
/// controller before being sent; `dateOfBirth` is an ISO local date string.
class EnrollCustomerForm {
  const EnrollCustomerForm({
    required this.fullName,
    required this.dateOfBirth,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.nationalIdNumber,
    required this.nationalIdType,
    this.addressIsland,
    this.addressCity,
    this.addressDistrict,
  });

  final String fullName;
  final String dateOfBirth; // YYYY-MM-DD
  final String phoneCountryCode;
  final String phoneNumber;
  final String nationalIdNumber;
  final String nationalIdType;
  final String? addressIsland;
  final String? addressCity;
  final String? addressDistrict;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
        'nationalIdNumber': nationalIdNumber,
        'nationalIdType': nationalIdType,
        if (addressIsland != null && addressIsland!.isNotEmpty)
          'addressIsland': addressIsland,
        if (addressCity != null && addressCity!.isNotEmpty)
          'addressCity': addressCity,
        if (addressDistrict != null && addressDistrict!.isNotEmpty)
          'addressDistrict': addressDistrict,
      };
}
