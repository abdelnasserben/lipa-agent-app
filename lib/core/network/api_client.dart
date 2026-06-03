import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/app_environment.dart';
import '../error/api_error.dart';

/// Signals that the session is gone and the UI must route to re-login.
/// The session controller listens for this.
typedef SessionExpiredCallback = void Function();

/// Thin wrapper over Dio that centralizes the shared API contract (spec §2):
/// envelopes, `Authorization` bearer, proactive + reactive token refresh,
/// `Idempotency-Key` / `X-Correlation-Id` plumbing, multipart KYC upload, and
/// error mapping.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    Dio? dio,
  })  : _config = config,
        // ignore: prefer_initializing_formals
        _tokenStore = tokenStore,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.baseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..headers['Content-Type'] = 'application/json'
      // Accept all <500 so we can branch on 4xx ourselves instead of throwing.
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final AppConfig _config;
  final TokenStore _tokenStore;
  final Dio _dio;

  SessionExpiredCallback? onSessionExpired;

  /// Attaches the bearer for protected endpoints. A caller can attach an
  /// explicit bearer (e.g. the single-use PIN_SETUP token) via the
  /// `Authorization` header — never overwrite it. Public auth routes pass
  /// `skipAuth`.
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth && options.headers['Authorization'] == null) {
      final token = await _validAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  /// Returns a non-expired access token, proactively refreshing if within the
  /// configured lead time. Returns null if no session.
  Future<String?> _validAccessToken() async {
    final tokens = _tokenStore.current ?? await _tokenStore.load();
    if (tokens == null) return null;
    if (tokens.shouldRefresh(_config.tokenRefreshLeadTime)) {
      final refreshed = await _refresh(tokens.refreshToken);
      return refreshed?.accessToken ?? tokens.accessToken;
    }
    return tokens.accessToken;
  }

  // Guards against parallel refresh storms.
  Future<AuthTokens?>? _refreshInFlight;

  Future<AuthTokens?> _refresh(String refreshToken) {
    return _refreshInFlight ??= _doRefresh(refreshToken).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<AuthTokens?> _doRefresh(String refreshToken) async {
    try {
      final res = await _dio.post(
        '/api/v1/auth/agent/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      if (res.statusCode == 200) {
        final data = (res.data is Map) ? res.data['data'] : null;
        if (data is Map<String, dynamic>) {
          final tokens = AuthTokens.fromJson(data);
          await _tokenStore.save(tokens);
          return tokens;
        }
      }
      // Refresh failed → session is dead.
      await _tokenStore.clear();
      onSessionExpired?.call();
      return null;
    } catch (_) {
      await _tokenStore.clear();
      onSessionExpired?.call();
      return null;
    }
  }

  void _onError(DioException e, ErrorInterceptorHandler handler) {
    // Transport-level failure (no response): surface a network ApiError.
    if (e.response == null) {
      handler.reject(
        DioException(
          requestOptions: e.requestOptions,
          error: ApiError.network(),
          type: e.type,
        ),
      );
      return;
    }
    handler.next(e);
  }

  // ── Verb helpers ───────────────────────────────────────────────────────
  // Each returns the raw Dio [Response], or throws a typed [ApiError] on 4xx.

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    String? bearer,
  }) =>
      _send(() =>
          _dio.get(path, queryParameters: query, options: _opts(bearer)));

  Future<Response<dynamic>> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    String? bearer,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.post(
            path,
            data: body,
            options: _opts(bearer, headers: headers, skipAuth: skipAuth),
          ));

  Future<Response<dynamic>> put(
    String path, {
    Object? body,
    String? bearer,
  }) =>
      _send(() => _dio.put(path, data: body, options: _opts(bearer)));

  Future<Response<dynamic>> delete(
    String path, {
    Object? body,
    String? bearer,
  }) =>
      _send(() => _dio.delete(path, data: body, options: _opts(bearer)));

  /// Multipart POST for KYC document upload (spec §5.5 / §11.4). Sends exactly
  /// the `documentType` + `file` fields and lets Dio set the multipart
  /// `Content-Type` boundary.
  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData formData,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.post(
            path,
            data: formData,
            options: Options(
              headers: {...?headers},
              contentType: 'multipart/form-data',
            ),
          ));

  Options _opts(
    String? bearer, {
    Map<String, String>? headers,
    bool skipAuth = false,
  }) {
    final h = <String, dynamic>{...?headers};
    if (bearer != null) h['Authorization'] = 'Bearer $bearer';
    return Options(headers: h, extra: {if (skipAuth) 'skipAuth': true});
  }

  /// Runs a request, retrying once after a reactive refresh on a 401, and
  /// converts any non-2xx response into a typed [ApiError].
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() run, {
    bool didRetry = false,
  }) async {
    Response<dynamic> res;
    try {
      res = await run();
    } on DioException catch (e) {
      if (e.error is ApiError) throw e.error as ApiError;
      throw ApiError.network();
    }

    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return res;

    // Reactive refresh-on-401 (once), then bail to re-login.
    if (status == 401 && !didRetry) {
      final tokens = _tokenStore.current ?? await _tokenStore.load();
      if (tokens != null) {
        final refreshed = await _refresh(tokens.refreshToken);
        if (refreshed != null) {
          return _send(run, didRetry: true);
        }
      }
      onSessionExpired?.call();
    }

    throw ApiError.fromResponse(status, res.data);
  }
}
