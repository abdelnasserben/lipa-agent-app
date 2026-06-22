import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/agent_profile.dart';
import '../agent/agent_providers.dart';
import '../cards/card_lookup_screen.dart';
import '../cards/card_sale_screen.dart';
import '../cashin/cash_in_screen.dart';
import '../cashout/cash_out_screen.dart';
import '../enroll/enroll_screen.dart';
import '../enroll/kyc_customer_screen.dart';

/// The "Opérer" hub (central FAB) — the launchpad for every agent operation,
/// grouped by area and gated on the agent's capabilities (spec §11.3).
class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Column(
      children: [
        const ScreenHeader(title: 'Opérer', subtitle: 'Toutes vos opérations'),
        Expanded(
          child: profile.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brand)),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: ErrorRetry(message: 'Profil indisponible.'),
            ),
            data: (p) => _Body(profile: p),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});
  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Section(title: 'Espèces', children: [
          if (profile.canDoCashIn)
            _OpRow(
              icon: Icons.south_west_rounded,
              title: 'Dépôt client (cash-in)',
              subtitle: 'Créditer le portefeuille d’un client',
              onTap: () => _push(context, const CashInScreen()),
            ),
          if (profile.canDoCashOut)
            _OpRow(
              icon: Icons.north_east_rounded,
              title: 'Retrait marchand (cash-out)',
              subtitle: 'Décaisser pour un marchand',
              onTap: () => _push(context, const CashOutScreen()),
            ),
          if (!profile.canDoCashIn && !profile.canDoCashOut)
            const _Disabled(
                text: 'Les opérations espèces ne sont pas activées sur votre compte.'),
        ]),
        const SizedBox(height: 18),
        _Section(title: 'Clients', children: [
          _OpRow(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Enrôler un client',
            subtitle: 'Créer un compte + KYC',
            onTap: () => _push(context, const EnrollScreen()),
          ),
          _OpRow(
            icon: Icons.badge_outlined,
            title: 'KYC client',
            subtitle: 'Compléter le dossier d’un client existant',
            onTap: () => _push(context, const KycCustomerScreen()),
          ),
        ]),
        const SizedBox(height: 18),
        _Section(title: 'Cartes', children: [
          _OpRow(
            icon: Icons.search_rounded,
            title: 'Rechercher une carte',
            subtitle: 'Par UID NFC — perte, vol, remplacement',
            onTap: () => _push(context, const CardLookupScreen()),
          ),
          if (profile.canSellCards)
            _OpRow(
              icon: Icons.add_card_rounded,
              title: 'Vendre une carte',
              subtitle: 'Depuis votre stock attribué',
              onTap: () => _push(context, const CardSaleScreen()),
            ),
        ]),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = children.whereType<Widget>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Text(title.toUpperCase(),
              style: AppText.ui(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: AppColors.inkLow,
                  letterSpacing: 0.8)),
        ),
        LipaCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _OpRow extends StatelessWidget {
  const _OpRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 21, color: AppColors.brandDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.ui(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppText.ui(size: 12.5, color: AppColors.inkMid)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }
}

class _Disabled extends StatelessWidget {
  const _Disabled({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: AppText.ui(size: 13, color: AppColors.inkMid)),
    );
  }
}
