import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/repositories/agent_repository.dart';
import '../data/repositories/auth_repository.dart';
import 'auth/token_store.dart';
import 'config/app_environment.dart';
import 'network/api_client.dart';
import 'scan/scanner.dart';

/// Build-time configuration (`--dart-define=ENV=local|prod`).
/// Overridable in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});

/// Dio-backed API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return ApiAgentRepository(ref.watch(apiClientProvider));
});

/// Hardware-scan seam (see core/scan/scanner.dart). Uses real NFC where the
/// device has a reader, and falls back to manual UID entry where it doesn't.
final cardScannerProvider = Provider<CardScanner>((ref) {
  return const NfcCardScanner();
});
