import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/code_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import 'security_controller.dart';

/// TOTP enrollment (spec §3.7): start → show secret/QR → confirm with a code.
/// Offers a path to revoke an existing enrollment.
class TotpEnrollScreen extends ConsumerStatefulWidget {
  const TotpEnrollScreen({super.key});

  @override
  ConsumerState<TotpEnrollScreen> createState() => _TotpEnrollScreenState();
}

class _TotpEnrollScreenState extends ConsumerState<TotpEnrollScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(totpControllerProvider);

    ref.listen(totpControllerProvider, (prev, next) {
      if (next.confirmed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('TOTP activé',
              style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.brandDeep,
        ));
        Navigator.of(context).pop();
      }
    });

    final setup = state.setup;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Configurer le TOTP',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (setup == null) ...[
                    const InfoBanner(
                      icon: Icons.qr_code_2_rounded,
                      text:
                          'Activez le double facteur (TOTP) avec une application comme Google Authenticator. Il sera demandé à chaque connexion et permet de réinitialiser votre PIN vous-même.',
                    ),
                    const SizedBox(height: 18),
                    LipaButton(
                      label: 'Commencer l’activation',
                      size: BtnSize.lg,
                      full: true,
                      loading: state.loading,
                      onPressed: () =>
                          ref.read(totpControllerProvider.notifier).start(),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 14),
                      Text(state.error!,
                          style:
                              AppText.ui(size: 13, color: AppColors.danger)),
                    ],
                  ] else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: FakeQr(size: 180, seedText: setup.secret),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Clé secrète',
                        style: AppText.ui(size: 13, weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _SecretBox(secret: setup.secret),
                    const SizedBox(height: 8),
                    Text(
                      'Scannez le QR (illustratif) ou saisissez la clé dans votre application, puis entrez le code à 6 chiffres.',
                      style: AppText.ui(
                          size: 12.5, color: AppColors.inkMid, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    const FieldLabelInline('Code de vérification'),
                    const SizedBox(height: 10),
                    CodeField(onChanged: (v) => setState(() => _code = v)),
                    if (state.error != null) ...[
                      const SizedBox(height: 14),
                      Text(state.error!,
                          style:
                              AppText.ui(size: 13, color: AppColors.danger)),
                    ],
                    const SizedBox(height: 22),
                    LipaButton(
                      label: 'Activer le TOTP',
                      size: BtnSize.lg,
                      full: true,
                      loading: state.loading,
                      onPressed: _code.length == 6
                          ? () => ref
                              .read(totpControllerProvider.notifier)
                              .confirm(_code)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FieldLabelInline extends StatelessWidget {
  const FieldLabelInline(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.ui(size: 13, weight: FontWeight.w600));
}

class _SecretBox extends StatelessWidget {
  const _SecretBox({required this.secret});
  final String secret;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: secret));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Clé copiée', style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.nearBlack,
          duration: const Duration(seconds: 1),
        ));
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(secret,
                  style: AppText.mono(
                      size: 14, weight: FontWeight.w600, letterSpacing: 1)),
            ),
            const Icon(Icons.copy_rounded, size: 16, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }
}
