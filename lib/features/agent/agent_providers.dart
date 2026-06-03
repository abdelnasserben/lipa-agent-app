import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/card.dart';
import '../../data/models/commission.dart';
import '../../data/models/notification.dart';
import '../../data/models/transaction.dart';

// Profile / balance / limits / summary are `autoDispose`: they tear down when
// the agent shell unmounts at logout, so they never refetch under a cleared
// token (which would 401 and then leave a stuck error cached) and always start
// fresh for the next agent on re-login. See SessionController.

final profileProvider = FutureProvider.autoDispose<AgentProfile>((ref) {
  return ref.watch(agentRepositoryProvider).getProfile();
});

final balanceProvider = FutureProvider.autoDispose<AgentBalance>((ref) {
  return ref.watch(agentRepositoryProvider).getBalance();
});

/// Null when no limit profile is assigned (404 → "not configured").
final limitsProvider = FutureProvider.autoDispose<AgentLimits?>((ref) {
  return ref.watch(agentRepositoryProvider).getLimits();
});

final dailySummaryProvider =
    FutureProvider.autoDispose<AgentDailySummary>((ref) {
  return ref.watch(agentRepositoryProvider).getDailySummary();
});

/// Recent wallet-scoped transactions (dashboard + activity tab).
final transactionsProvider =
    FutureProvider.autoDispose<List<AgentTransaction>>((ref) async {
  final page = await ref.watch(agentRepositoryProvider).getTransactions();
  return page.items;
});

final transactionProvider = FutureProvider.autoDispose
    .family<AgentTransaction, String>((ref, id) {
  return ref.watch(agentRepositoryProvider).getTransaction(id);
});

/// Wallet statement entries for the chosen window. A null range = full history.
///
/// The backend binds `from`/`to` as ISO-8601 `Instant`s (date-time), so a bare
/// `yyyy-MM-dd` fails to parse and — since the params are optional — is silently
/// dropped, returning everything. We send full UTC instants and make the window
/// inclusive of the last day by ending at the start of the day *after* `end`.
final statementsProvider = FutureProvider.autoDispose
    .family<List<StatementEntry>, DateTimeRange?>((ref, range) async {
  // The picker yields local midnight; convert to UTC so the boundary is exact.
  String? iso(DateTime? d) => d?.toUtc().toIso8601String();
  final from = range == null
      ? null
      : DateTime(range.start.year, range.start.month, range.start.day);
  // Exclusive upper bound at the next midnight → the whole `end` day is covered.
  final to = range == null
      ? null
      : DateTime(range.end.year, range.end.month, range.end.day + 1);
  final page = await ref.watch(agentRepositoryProvider).getStatements(
        from: iso(from),
        to: iso(to),
      );
  return page.items;
});

/// Assigned card stock (default ASSIGNED_TO_AGENT), used by the cards tab and
/// the card-sale / replacement pickers.
final cardStockProvider =
    FutureProvider.autoDispose<List<CardStockItem>>((ref) {
  return ref.watch(agentRepositoryProvider).getCardStock();
});

final commissionsProvider =
    FutureProvider.autoDispose<List<Commission>>((ref) async {
  final page = await ref.watch(agentRepositoryProvider).getCommissions();
  return page.items;
});

/// Unread badge count — refreshed on demand / poll.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(agentRepositoryProvider).getUnreadCount();
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(agentRepositoryProvider).getNotifications();
});
