import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/commission.dart';
import '../../data/models/enums.dart';
import '../agent/agent_providers.dart';

/// Commission payout history (spec §5.7).
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commissions = ref.watch(commissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Commissions',
              subtitle: 'Vos versements',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(commissionsProvider);
                  await ref.read(commissionsProvider.future);
                },
                child: commissions.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand)),
                  error: (_, _) => ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: ErrorRetry(message: 'Commissions indisponibles.'),
                    ),
                  ]),
                  data: (items) {
                    if (items.isEmpty) {
                      return ListView(children: const [
                        EmptyState(
                          icon: Icons.savings_outlined,
                          title: 'Aucune commission',
                          message:
                              'Vos commissions sur dépôts, retraits et ventes apparaîtront ici.',
                        ),
                      ]);
                    }
                    final total = items
                        .where((c) => c.status == PayoutStatus.paid)
                        .fold<int>(0, (s, c) => s + c.amount);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _TotalCard(total: total),
                        const SizedBox(height: 16),
                        for (final c in items) _CommissionRow(commission: c),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        color: AppColors.nearBlack,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOTAL VERSÉ',
                style: AppText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(fmtKmfNoUnit(total),
                    style: AppText.mono(
                        size: 30,
                        weight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(width: 8),
                Text('KMF',
                    style: AppText.mono(size: 13, color: Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  const _CommissionRow({required this.commission});
  final Commission commission;

  @override
  Widget build(BuildContext context) {
    final c = commission;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LipaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.savings_outlined,
                  size: 20, color: AppColors.brandDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sur ${fmtKmf(c.basisAmount)}',
                      style: AppText.ui(size: 13.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${c.settlementMode.frLabel}${c.createdAt != null ? ' · ${fmtDateFr(c.createdAt!)}' : ''}',
                    style: AppText.ui(size: 12, color: AppColors.inkLow),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtKmf(c.amount, signed: true),
                    style: AppText.mono(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.brandDeep)),
                const SizedBox(height: 4),
                PayoutStatusPill(status: c.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
