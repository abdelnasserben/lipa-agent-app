import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import '../../data/models/agent_profile.dart';
import '../activity/statement_screen.dart';
import '../activity/transaction_detail_screen.dart';
import '../activity/tx_row.dart';
import '../agent/agent_providers.dart';
import '../cashin/cash_in_screen.dart';
import '../cashout/cash_out_screen.dart';
import '../enroll/enroll_screen.dart';
import '../notifications/notifications_screen.dart';

/// Agent dashboard. The float balance hero + daily summary are the operator's
/// most-watched numbers; quick actions jump into the core cash journeys.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final balance = ref.watch(balanceProvider);
    final summary = ref.watch(dailySummaryProvider);
    final activity = ref.watch(transactionsProvider);
    final unread = ref.watch(unreadCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(balanceProvider);
        ref.invalidate(dailySummaryProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(unreadCountProvider);
        await ref.read(transactionsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Greeting + bell.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Agent Lipa',
                          style: AppText.ui(size: 13, color: AppColors.inkMid)),
                      const SizedBox(height: 2),
                      Text(
                        profile.maybeWhen(
                            data: (p) => p.fullName, orElse: () => '…'),
                        style: AppText.ui(
                            size: 19,
                            weight: FontWeight.w700,
                            letterSpacing: -0.28),
                      ),
                    ],
                  ),
                ),
                CircleButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                  badge: unread.maybeWhen(
                    data: (n) => n > 0 ? CountBadge(count: n) : null,
                    orElse: () => null,
                  ),
                  child: const Icon(Icons.notifications_none),
                ),
              ],
            ),
          ),

          // Float balance hero card.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FloatCard(
              balance: balance,
              profile: profile,
              onCashIn: () => _push(context, const CashInScreen()),
              onCashOut: () => _push(context, const CashOutScreen()),
              onStatement: () => _push(context, const StatementScreen()),
            ),
          ),

          // Daily summary.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
            child: Text("Aujourd'hui",
                style: AppText.ui(size: 15, weight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SummaryGrid(summary: summary),
          ),

          // Quick operations.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
            child: Text('Opérations rapides',
                style: AppText.ui(size: 15, weight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: profile.maybeWhen(
              data: (p) => _QuickOps(profile: p),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // Recent activity.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
            child: Text('Activité récente',
                style: AppText.ui(size: 15, weight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: activity.when(
              loading: () => const _ActivitySkeleton(),
              error: (e, _) => const ErrorRetry(
                  message: 'Impossible de charger l’activité.'),
              data: (txs) => txs.isEmpty
                  ? LipaCard(
                      padding: const EdgeInsets.all(20),
                      child: Text('Aucune opération pour le moment.',
                          style:
                              AppText.ui(size: 13, color: AppColors.inkMid)),
                    )
                  : LipaCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < txs.take(5).length; i++)
                            TxRow(
                              tx: txs[i],
                              divider: i > 0,
                              onTap: () => _push(context,
                                  TransactionDetailScreen(txId: txs[i].id)),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _FloatCard extends StatefulWidget {
  const _FloatCard({
    required this.balance,
    required this.profile,
    required this.onCashIn,
    required this.onCashOut,
    required this.onStatement,
  });
  final AsyncValue<AgentBalance> balance;
  final AsyncValue<AgentProfile> profile;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;
  final VoidCallback onStatement;

  @override
  State<_FloatCard> createState() => _FloatCardState();
}

class _FloatCardState extends State<_FloatCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final threshold = widget.profile.maybeWhen(
        data: (p) => p.floatAlertThreshold, orElse: () => 0);
    final below = widget.balance.maybeWhen(
        data: (b) => b.availableBalance < threshold && threshold > 0,
        orElse: () => false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: Stack(
        children: [
          Container(
            color: AppColors.nearBlack,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FLOAT DISPONIBLE',
                        style: AppText.ui(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 1)),
                    InkWell(
                      onTap: () => setState(() => _hidden = !_hidden),
                      child: Icon(
                          _hidden ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                widget.balance.when(
                  loading: () => Text('••• •••',
                      style: AppText.mono(
                          size: 38,
                          weight: FontWeight.w600,
                          color: Colors.white)),
                  error: (_, _) => Text('—',
                      style: AppText.mono(size: 38, color: Colors.white)),
                  data: (b) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _hidden ? '••• •••' : fmtKmfNoUnit(b.availableBalance),
                        style: AppText.mono(
                            size: 38,
                            weight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text('KMF',
                          style:
                              AppText.mono(size: 14, color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                widget.balance.maybeWhen(
                  data: (b) => Text.rich(
                    TextSpan(
                      style: AppText.ui(size: 12.5, color: Colors.white54),
                      children: [
                        TextSpan(
                            text:
                                '${fmtKmfNoUnit(b.frozenBalance)} KMF gelés · Portefeuille '),
                        TextSpan(
                          text: '● ${b.walletStatus.frLabel}',
                          style: TextStyle(
                              color: b.walletStatus.isActive
                                  ? const Color(0xFF8FD1A8)
                                  : const Color(0xFFE0A24A)),
                        ),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (below) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A2A12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border:
                          Border.all(color: const Color(0xFF6B4E1E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: Color(0xFFE0A24A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Float sous le seuil d’alerte (${fmtKmf(threshold)}). Pensez à réapprovisionner.',
                            style: AppText.ui(
                                size: 12,
                                color: const Color(0xFFE6C998),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroAction(
                        icon: Icons.south_west_rounded,
                        label: 'Dépôt',
                        onTap: widget.onCashIn),
                    const SizedBox(width: 8),
                    _HeroAction(
                        icon: Icons.north_east_rounded,
                        label: 'Retrait',
                        onTap: widget.onCashOut),
                    const SizedBox(width: 8),
                    _HeroAction(
                        icon: Icons.description_outlined,
                        label: 'Relevé',
                        onTap: widget.onStatement),
                  ],
                ),
              ],
            ),
          ),
          const GridBackground(),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 6),
              Text(label,
                  style: AppText.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final AsyncValue<AgentDailySummary> summary;

  @override
  Widget build(BuildContext context) {
    return summary.when(
      loading: () => const _ActivitySkeleton(),
      error: (_, _) =>
          const ErrorRetry(message: 'Résumé indisponible.'),
      data: (s) => Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Volume',
              value: fmtKmfNoUnit(s.totalCompletedAmountToday),
              unit: 'KMF',
              icon: Icons.swap_horiz_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(
              label: 'Opérations',
              value: '${s.totalCompletedCountToday}',
              icon: Icons.tag_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(
              label: 'Commission',
              value: fmtKmfNoUnit(s.commissionEarnedToday),
              unit: 'KMF',
              icon: Icons.savings_outlined,
              accent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.accent = false,
  });
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18, color: accent ? AppColors.brand : AppColors.inkLow),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: AppText.mono(
                        size: 17,
                        weight: FontWeight.w600,
                        color: accent ? AppColors.brandDeep : AppColors.inkHi)),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(unit!,
                      style:
                          AppText.mono(size: 10, color: AppColors.inkLow)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.ui(size: 11.5, color: AppColors.inkMid)),
        ],
      ),
    );
  }
}

/// Capability-gated quick-op chips (spec §11.3): hidden when the agent can't.
class _QuickOps extends StatelessWidget {
  const _QuickOps({required this.profile});
  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (profile.canDoCashIn)
        _OpTile(
            icon: Icons.south_west_rounded,
            label: 'Dépôt client',
            sub: 'Cash-in',
            onTap: () => _push(context, const CashInScreen())),
      if (profile.canDoCashOut)
        _OpTile(
            icon: Icons.north_east_rounded,
            label: 'Retrait marchand',
            sub: 'Cash-out',
            onTap: () => _push(context, const CashOutScreen())),
      _OpTile(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Enrôler un client',
          sub: 'KYC',
          onTap: () => _push(context, const EnrollScreen())),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: tiles,
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _OpTile extends StatelessWidget {
  const _OpTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 20, color: AppColors.brandDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.ui(size: 13.5, weight: FontWeight.w600)),
                    Text(sub,
                        style:
                            AppText.ui(size: 11.5, color: AppColors.inkLow)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();
  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.brand),
        ),
      ),
    );
  }
}
