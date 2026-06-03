import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/code_field.dart';
import '../../core/widgets/common.dart';
import 'security_controller.dart';

/// TOTP revocation (spec §3.7): step up with a current 6-digit code.
class TotpRevokeScreen extends ConsumerStatefulWidget {
  const TotpRevokeScreen({super.key});

  @override
  ConsumerState<TotpRevokeScreen> createState() => _TotpRevokeScreenState();
}

class _TotpRevokeScreenState extends ConsumerState<TotpRevokeScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(totpControllerProvider);

    ref.listen(totpControllerProvider, (prev, next) {
      if (next.revoked) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('TOTP révoqué', style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.nearBlack,
        ));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Révoquer le TOTP',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const InfoBanner(
                    kind: PillKind.warn,
                    icon: Icons.warning_amber_rounded,
                    text:
                        'Désactiver le TOTP réduit la sécurité de votre compte et vous empêchera de réinitialiser votre PIN vous-même.',
                  ),
                  const SizedBox(height: 18),
                  Text('Saisissez un code TOTP actuel pour confirmer',
                      style: AppText.ui(size: 13, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  CodeField(onChanged: (v) => setState(() => _code = v)),
                  if (state.error != null) ...[
                    const SizedBox(height: 14),
                    Text(state.error!,
                        style: AppText.ui(size: 13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 22),
                  LipaButton(
                    label: 'Révoquer le TOTP',
                    variant: BtnVariant.danger,
                    size: BtnSize.lg,
                    full: true,
                    loading: state.loading,
                    onPressed: _code.length == 6
                        ? () => ref
                            .read(totpControllerProvider.notifier)
                            .revoke(_code)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
