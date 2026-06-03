import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import 'change_pin_screen.dart';
import 'security_controller.dart';
import 'totp_enroll_screen.dart';
import 'totp_revoke_screen.dart';

/// Security hub: change PIN, manage TOTP (spec §3.6 / §3.7).
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totpOn = ref.watch(totpEnrolledProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Sécurité',
              subtitle: 'PIN et authentification',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const InfoBanner(
                    icon: Icons.shield_outlined,
                    text:
                        'Protégez votre compte agent : un PIN fort et le TOTP réduisent les risques de fraude au comptoir.',
                  ),
                  const SizedBox(height: 18),
                  LipaCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.password_rounded,
                          title: 'Changer mon PIN',
                          subtitle: 'Nécessite votre PIN actuel',
                          onTap: () => _push(context, const ChangePinScreen()),
                        ),
                        // Offer revoke only when TOTP is active, and enroll only
                        // when it isn't (mirrors the customer app).
                        _Row(
                          icon: totpOn
                              ? Icons.no_encryption_rounded
                              : Icons.qr_code_2_rounded,
                          title: totpOn
                              ? 'Révoquer le TOTP'
                              : 'Configurer le TOTP',
                          subtitle: totpOn
                              ? 'Désactiver le double facteur (code requis)'
                              : 'Activer le double facteur d’authentification',
                          trailing: StatusPill(
                            label: totpOn ? 'Activé' : 'Inactif',
                            kind: totpOn ? PillKind.success : PillKind.neutral,
                          ),
                          danger: totpOn,
                          onTap: () => _push(
                            context,
                            totpOn
                                ? const TotpRevokeScreen()
                                : const TotpEnrollScreen(),
                          ),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink;
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
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.ui(
                          size: 14.5, weight: FontWeight.w600, color: fg)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppText.ui(size: 12.5, color: AppColors.inkMid)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }
}
