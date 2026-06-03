import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_envelopes.dart';
import '../models/agent_profile.dart';
import '../models/card.dart';
import '../models/cash_result.dart';
import '../models/commission.dart';
import '../models/enrollment.dart';
import '../models/enums.dart';
import '../models/lookup.dart';
import '../models/notification.dart';
import '../models/transaction.dart';

/// Generates a fresh idempotency key per new financial intent (spec §11.2).
String newIdempotencyKey() => const Uuid().v4();

/// A picked KYC file ready for multipart upload. Kept transport-agnostic so the
/// upload path doesn't import `dart:io` directly (the picker yields the bytes).
class KycUploadFile {
  const KycUploadFile({
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String? contentType; // e.g. "image/jpeg"
}

/// Agent portal surface (spec §5.2–§5.8). Implementation: [ApiAgentRepository].
abstract class AgentRepository {
  // Profile / balance / limits / summary
  Future<AgentProfile> getProfile();
  Future<AgentBalance> getBalance();

  /// Null when no limit profile is assigned (spec §5.2: 404 → "not configured").
  Future<AgentLimits?> getLimits();
  Future<AgentDailySummary> getDailySummary();

  // History
  Future<PagedResponse<AgentTransaction>> getTransactions({
    String? cursor,
    String? status,
    String? type,
    String? from,
    String? to,
  });
  Future<AgentTransaction> getTransaction(String id);
  Future<PagedResponse<StatementEntry>> getStatements({
    String? cursor,
    String? from,
    String? to,
  });

  // Lookups
  Future<CustomerLookup> lookupCustomer({
    required String phoneCountryCode,
    required String phoneNumber,
  });
  Future<MerchantLookup> lookupMerchant({
    required String phoneCountryCode,
    required String phoneNumber,
  });
  Future<CardLookup> lookupCard(String nfcUid);

  // Cash operations
  Future<AgentCashInResult> cashIn({
    required String idempotencyKey,
    required String customerId,
    required int amount,
  });

  /// Cash-out with the control-tier loop (spec §8). Reuse the same
  /// [idempotencyKey] across PIN / confirmation resubmits.
  Future<AgentCashOutResult> cashOut({
    required String idempotencyKey,
    required String merchantId,
    required int amount,
    String? merchantPin,
    bool? confirmationAcknowledged,
  });

  // Enrollment + KYC
  Future<EnrollCustomerResult> enrollCustomer(EnrollCustomerForm form);
  Future<KycDocument> uploadKycDocument({
    required String customerId,
    required KycDocumentType documentType,
    required KycUploadFile file,
  });
  Future<List<KycDocument>> getKycDocuments(String customerId);

  // Cards + stock
  Future<List<CardStockItem>> getCardStock({CardStockStatus? status});
  Future<CardSaleResult> sellCard({
    required String idempotencyKey,
    required String customerId,
    required String nfcUid,
    required int cardPrice,
  });
  Future<CardLookup> reportCardLost({
    required String customerId,
    required String cardId,
  });
  Future<CardLookup> reportCardStolen({
    required String customerId,
    required String cardId,
  });
  Future<CardReplacementResult> replaceCard({
    required String idempotencyKey,
    required String customerId,
    required String cardId,
    required String stockId,
    required int replacementFee,
  });

  // Commissions
  Future<PagedResponse<Commission>> getCommissions({
    String? cursor,
    String? status,
  });

  // Notifications (shared inbox)
  Future<List<AppNotification>> getNotifications({int limit = 20});
  Future<int> getUnreadCount();
  Future<void> markNotificationRead(String id);
  Future<int> markAllNotificationsRead();
}

class ApiAgentRepository implements AgentRepository {
  ApiAgentRepository(this._api);

  final ApiClient _api;
  static const _base = '/api/v1/agent';
  static const _notif = '/api/v1/notifications';

  // Cached for transaction-direction derivation (which wallet side moved).
  String? _walletId;

  @override
  Future<AgentProfile> getProfile() async {
    final res = await _api.get('$_base/me');
    final profile = unwrapData(
        res.data, (d) => AgentProfile.fromJson(d as Map<String, dynamic>));
    _walletId = profile.walletId;
    return profile;
  }

  @override
  Future<AgentBalance> getBalance() async {
    final res = await _api.get('$_base/balance');
    final b = unwrapData(
        res.data, (d) => AgentBalance.fromJson(d as Map<String, dynamic>));
    _walletId ??= b.walletId;
    return b;
  }

  @override
  Future<AgentLimits?> getLimits() async {
    try {
      final res = await _api.get('$_base/limits');
      return unwrapData(
          res.data, (d) => AgentLimits.fromJson(d as Map<String, dynamic>));
    } catch (_) {
      // 404 → no profile assigned (spec §5.2): treat as "not configured".
      return null;
    }
  }

  @override
  Future<AgentDailySummary> getDailySummary() async {
    final res = await _api.get('$_base/summary/daily');
    return unwrapData(
        res.data, (d) => AgentDailySummary.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<PagedResponse<AgentTransaction>> getTransactions({
    String? cursor,
    String? status,
    String? type,
    String? from,
    String? to,
  }) async {
    final res = await _api.get('$_base/transactions', query: {
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
      if (type != null) 'type': type,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return PagedResponse.fromBody(
        res.data, (m) => AgentTransaction.fromJson(m, walletId: _walletId));
  }

  @override
  Future<AgentTransaction> getTransaction(String id) async {
    final res = await _api.get('$_base/transactions/$id');
    return unwrapData(
        res.data,
        (d) => AgentTransaction.fromJson(d as Map<String, dynamic>,
            walletId: _walletId));
  }

  @override
  Future<PagedResponse<StatementEntry>> getStatements({
    String? cursor,
    String? from,
    String? to,
  }) async {
    final res = await _api.get('$_base/statements', query: {
      if (cursor != null) 'cursor': cursor,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return PagedResponse.fromBody(res.data, StatementEntry.fromJson);
  }

  @override
  Future<CustomerLookup> lookupCustomer({
    required String phoneCountryCode,
    required String phoneNumber,
  }) async {
    final res = await _api.get('$_base/lookup', query: {
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': phoneNumber,
    });
    return unwrapData(
        res.data, (d) => CustomerLookup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<MerchantLookup> lookupMerchant({
    required String phoneCountryCode,
    required String phoneNumber,
  }) async {
    final res = await _api.get('$_base/merchants/lookup', query: {
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': phoneNumber,
    });
    return unwrapData(
        res.data, (d) => MerchantLookup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CardLookup> lookupCard(String nfcUid) async {
    final res = await _api.get('$_base/cards/lookup', query: {'nfcUid': nfcUid});
    return unwrapData(
        res.data, (d) => CardLookup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<AgentCashInResult> cashIn({
    required String idempotencyKey,
    required String customerId,
    required int amount,
  }) async {
    final res = await _api.post(
      '$_base/cash-in',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'customerId': customerId, 'amount': amount},
    );
    return unwrapData(
        res.data, (d) => AgentCashInResult.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<AgentCashOutResult> cashOut({
    required String idempotencyKey,
    required String merchantId,
    required int amount,
    String? merchantPin,
    bool? confirmationAcknowledged,
  }) async {
    final res = await _api.post(
      '$_base/cash-out',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'merchantId': merchantId,
        'amount': amount,
        if (merchantPin != null) 'merchantPin': merchantPin,
        if (confirmationAcknowledged != null)
          'confirmationAcknowledged': confirmationAcknowledged,
      },
    );
    final body = res.data;
    final data = (body is Map<String, dynamic> && body['data'] is Map)
        ? body['data'] as Map<String, dynamic>
        : (body is Map<String, dynamic> ? body : const <String, dynamic>{});
    // Branch on HTTP status, not the body (spec §5.4 / §8).
    return AgentCashOutResult.fromJson(data, httpStatus: res.statusCode ?? 200);
  }

  @override
  Future<EnrollCustomerResult> enrollCustomer(EnrollCustomerForm form) async {
    final res = await _api.post('$_base/customers/enroll', body: form.toJson());
    return unwrapData(res.data,
        (d) => EnrollCustomerResult.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<KycDocument> uploadKycDocument({
    required String customerId,
    required KycDocumentType documentType,
    required KycUploadFile file,
  }) async {
    final formData = FormData.fromMap({
      'documentType': documentType.wire,
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.filename,
      ),
    });
    final res = await _api.postMultipart(
      '$_base/customers/$customerId/kyc-documents',
      formData: formData,
    );
    return unwrapData(
        res.data, (d) => KycDocument.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<List<KycDocument>> getKycDocuments(String customerId) async {
    final res = await _api.get('$_base/customers/$customerId/kyc-documents');
    return parseDataList(res.data, KycDocument.fromJson);
  }

  @override
  Future<List<CardStockItem>> getCardStock({CardStockStatus? status}) async {
    final res = await _api.get('$_base/card-stock', query: {
      if (status != null) 'status': status.wire,
    });
    return PagedResponse.fromBody(res.data, CardStockItem.fromJson).items;
  }

  @override
  Future<CardSaleResult> sellCard({
    required String idempotencyKey,
    required String customerId,
    required String nfcUid,
    required int cardPrice,
  }) async {
    final res = await _api.post(
      '$_base/card-sell',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'customerId': customerId,
        'nfcUid': nfcUid,
        'cardPrice': cardPrice,
      },
    );
    return unwrapData(
        res.data, (d) => CardSaleResult.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CardLookup> reportCardLost({
    required String customerId,
    required String cardId,
  }) async {
    final res = await _api
        .post('$_base/customers/$customerId/cards/$cardId/report-lost');
    return unwrapData(
        res.data, (d) => CardLookup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CardLookup> reportCardStolen({
    required String customerId,
    required String cardId,
  }) async {
    final res = await _api
        .post('$_base/customers/$customerId/cards/$cardId/report-stolen');
    return unwrapData(
        res.data, (d) => CardLookup.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CardReplacementResult> replaceCard({
    required String idempotencyKey,
    required String customerId,
    required String cardId,
    required String stockId,
    required int replacementFee,
  }) async {
    final res = await _api.post(
      '$_base/customers/$customerId/cards/$cardId/replace',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'stockId': stockId, 'replacementFee': replacementFee},
    );
    return unwrapData(res.data,
        (d) => CardReplacementResult.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<PagedResponse<Commission>> getCommissions({
    String? cursor,
    String? status,
  }) async {
    final res = await _api.get('$_base/commissions', query: {
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
    });
    return PagedResponse.fromBody(res.data, Commission.fromJson);
  }

  @override
  Future<List<AppNotification>> getNotifications({int limit = 20}) async {
    final res = await _api.get(_notif, query: {'limit': limit});
    return parseDataList(res.data, AppNotification.fromJson);
  }

  @override
  Future<int> getUnreadCount() async {
    final res = await _api.get('$_notif/unread');
    return unwrapData(res.data, (d) {
      if (d is Map<String, dynamic>) return (d['unread'] ?? 0) as int;
      return 0;
    });
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _api.post('$_notif/$id/read');
  }

  @override
  Future<int> markAllNotificationsRead() async {
    final res = await _api.post('$_notif/read-all');
    return unwrapData(res.data, (d) {
      if (d is Map<String, dynamic>) return (d['updated'] ?? 0) as int;
      return 0;
    });
  }
}
