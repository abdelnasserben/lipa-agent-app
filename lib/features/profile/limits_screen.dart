import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/agent_profile.dart';
import '../agent/agent_providers.dart';

/// Assigned transaction limits (spec §5.2). Null when no profile is assigned.
class LimitsScreen extends ConsumerWidget {
  const LimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(limitsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Plafonds',
              subtitle: 'Limites de transaction',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: limits.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: ErrorRetry(message: 'Plafonds indisponibles.'),
                ),
                data: (l) => l == null
                    ? const EmptyState(
                        icon: Icons.speed_rounded,
                        title: 'Aucun plafond configuré',
                        message:
                            'Aucun profil de limites n’est attribué à votre compte.',
                      )
                    : _Body(limits: l),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.limits});
  final AgentLimits limits;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        LipaCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined,
                  color: AppColors.brandDeep, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(limits.profileName,
                        style:
                            AppText.ui(size: 15, weight: FontWeight.w700)),
                    Text('KYC requis : ${limits.requiredKycLevel.frLabel}',
                        style:
                            AppText.ui(size: 12.5, color: AppColors.inkMid)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Par transaction',
            style: AppText.ui(size: 13, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row('Minimum', limits.minTransactionAmount),
              _row('Maximum', limits.maxTransactionAmount, last: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Cumuls',
            style: AppText.ui(size: 13, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row('Plafond journalier', limits.maxDailyAmount),
              _row('Plafond hebdomadaire', limits.maxWeeklyAmount),
              _row('Plafond mensuel', limits.maxMonthlyAmount),
              _countRow('Transactions / jour', limits.maxDailyTransactionCount),
              _countRow('Transactions / mois', limits.maxMonthlyTransactionCount,
                  last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, int? value, {bool last = false}) => DetailRow(
        label: label,
        value: value == null ? 'Non défini' : fmtKmf(value),
        mono: value != null,
        last: last,
      );

  Widget _countRow(String label, int? value, {bool last = false}) => DetailRow(
        label: label,
        value: value == null ? 'Non défini' : '$value',
        mono: value != null,
        last: last,
      );
}
