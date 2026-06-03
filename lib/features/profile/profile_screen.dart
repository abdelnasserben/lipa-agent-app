import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/agent_profile.dart';
import '../agent/agent_providers.dart';
import '../auth/session_controller.dart';
import '../commissions/commissions_screen.dart';
import '../security/security_screen.dart';
import 'limits_screen.dart';

/// Profile tab: agent identity, capabilities, and entry points to commissions,
/// limits, and security (PIN / TOTP). Logout lives here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Column(
      children: [
        const ScreenHeader(title: 'Profil'),
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

class _Body extends ConsumerWidget {
  const _Body({required this.profile});
  final AgentProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Identity header.
        LipaCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.nearBlack,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(_initials(profile.fullName),
                    style: AppText.ui(
                        size: 20,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style:
                            AppText.ui(size: 17, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(profile.phonePretty,
                        style:
                            AppText.mono(size: 13, color: AppColors.inkMid)),
                    const SizedBox(height: 8),
                    GenericStatusPill(
                        label: profile.status.frLabel,
                        active: profile.status.isActive),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Account details.
        LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(label: 'Référence agent', value: profile.externalRef),
              if (profile.zone != null && profile.zone!.isNotEmpty)
                DetailRow(label: 'Zone', value: profile.zone!),
              DetailRow(label: 'Niveau KYC', value: profile.kycLevel.frLabel),
              if (profile.contractRef != null)
                DetailRow(label: 'Contrat', value: profile.contractRef!),
              DetailRow(
                  label: 'Seuil d’alerte float',
                  value: fmtKmf(profile.floatAlertThreshold),
                  mono: true,
                  last: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Capabilities (spec §10.3 gating flags).
        Text('Autorisations',
            style: AppText.ui(size: 13, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Cap(label: 'Dépôts', on: profile.canDoCashIn),
            _Cap(label: 'Retraits', on: profile.canDoCashOut),
            _Cap(label: 'Vente de cartes', on: profile.canSellCards),
          ],
        ),
        const SizedBox(height: 20),

        // Navigation.
        _NavCard(children: [
          _NavRow(
            icon: Icons.savings_outlined,
            label: 'Commissions',
            onTap: () => _push(context, const CommissionsScreen()),
          ),
          _NavRow(
            icon: Icons.speed_rounded,
            label: 'Plafonds',
            onTap: () => _push(context, const LimitsScreen()),
          ),
          _NavRow(
            icon: Icons.shield_outlined,
            label: 'Sécurité (PIN, TOTP)',
            onTap: () => _push(context, const SecurityScreen()),
            last: true,
          ),
        ]),
        const SizedBox(height: 20),

        LipaButton(
          label: 'Se déconnecter',
          variant: BtnVariant.dangerOutline,
          size: BtnSize.lg,
          full: true,
          icon: const Icon(Icons.logout_rounded),
          onPressed: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Se déconnecter',
            style: AppText.ui(size: 17, weight: FontWeight.w700)),
        content: Text('Voulez-vous vraiment vous déconnecter ?',
            style: AppText.ui(size: 14, color: AppColors.inkMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler',
                  style: AppText.ui(size: 14, color: AppColors.inkMid))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Déconnexion',
                  style: AppText.ui(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isEmpty ? '?' : parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _Cap extends StatelessWidget {
  const _Cap({required this.label, required this.on});
  final String label;
  final bool on;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: on ? AppColors.brandSoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: on ? AppColors.brandSoft : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.check_circle : Icons.remove_circle_outline,
              size: 15,
              color: on ? AppColors.brandDeep : AppColors.inkLow),
          const SizedBox(width: 6),
          Text(label,
              style: AppText.ui(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: on ? AppColors.brandDeep : AppColors.inkMid)),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LipaCard(padding: EdgeInsets.zero, child: Column(children: children));
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppText.ui(size: 14.5, weight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }
}
