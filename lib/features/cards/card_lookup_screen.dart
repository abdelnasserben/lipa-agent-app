import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/enums.dart';
import '../../data/models/lookup.dart';
import 'card_replace_screen.dart';

/// Card lookup by scanned NFC UID (spec §5.4 / §5.6). The result drives the
/// report-lost / report-stolen / replace actions for a customer card.
class CardLookupScreen extends ConsumerStatefulWidget {
  const CardLookupScreen({super.key});

  @override
  ConsumerState<CardLookupScreen> createState() => _CardLookupScreenState();
}

class _CardLookupScreenState extends ConsumerState<CardLookupScreen> {
  CardLookup? _card;
  bool _busy = false;
  String? _error;

  Future<void> _scan() async {
    final uid = await ref.read(cardScannerProvider).scanCardUid(context);
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final card = await ref.read(agentRepositoryProvider).lookupCard(uid);
      setState(() => _card = card);
    } on ApiError catch (e) {
      setState(() => _error = frenchMessageForError(e));
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(bool stolen) async {
    final card = _card;
    if (card == null || card.customerId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(stolen ? 'Déclarer volée' : 'Déclarer perdue',
            style: AppText.ui(size: 17, weight: FontWeight.w700)),
        content: Text(
          stolen
              ? 'Confirmer que cette carte est volée ? Elle sera bloquée immédiatement.'
              : 'Confirmer que cette carte est perdue ? Elle sera bloquée immédiatement.',
          style: AppText.ui(size: 14, color: AppColors.inkMid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: AppText.ui(size: 14, color: AppColors.inkMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmer',
                style: AppText.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(agentRepositoryProvider);
      final updated = stolen
          ? await repo.reportCardStolen(
              customerId: card.customerId!, cardId: card.cardId)
          : await repo.reportCardLost(
              customerId: card.customerId!, cardId: card.cardId);
      setState(() => _card = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(stolen ? 'Carte déclarée volée' : 'Carte déclarée perdue',
              style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.nearBlack,
        ));
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(frenchMessageForError(e),
              style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Rechercher une carte',
              subtitle: 'Par UID NFC',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const InfoBanner(
                    icon: Icons.nfc_rounded,
                    text:
                        'Scannez la carte du client (ou saisissez son UID) pour la retrouver, puis déclarez-la perdue/volée ou remplacez-la.',
                  ),
                  const SizedBox(height: 16),
                  LipaButton(
                    label: card == null ? 'Scanner la carte' : 'Scanner une autre carte',
                    icon: const Icon(Icons.nfc_rounded),
                    size: BtnSize.lg,
                    full: true,
                    loading: _busy && card == null,
                    onPressed: _busy ? null : _scan,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                        kind: PillKind.declined,
                        icon: Icons.error_outline,
                        text: _error!),
                  ],
                  if (card != null) ...[
                    const SizedBox(height: 20),
                    _CardCard(card: card),
                    const SizedBox(height: 16),
                    if (card.isLinked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: LipaButton(
                              label: 'Perdue',
                              icon: const Icon(Icons.help_outline_rounded),
                              variant: BtnVariant.dangerOutline,
                              size: BtnSize.lg,
                              loading: _busy,
                              onPressed: card.status == CardStatus.lost
                                  ? null
                                  : () => _report(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LipaButton(
                              label: 'Volée',
                              icon: const Icon(Icons.report_gmailerrorred_rounded),
                              variant: BtnVariant.danger,
                              size: BtnSize.lg,
                              loading: _busy,
                              onPressed: card.status == CardStatus.stolen
                                  ? null
                                  : () => _report(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LipaButton(
                        label: 'Remplacer la carte',
                        icon: const Icon(Icons.sync_rounded),
                        variant: BtnVariant.secondary,
                        size: BtnSize.lg,
                        full: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CardReplaceScreen(card: card),
                          ),
                        ),
                      ),
                    ] else
                      const InfoBanner(
                        kind: PillKind.info,
                        icon: Icons.info_outline,
                        text:
                            'Cette carte n’est pas encore liée à un client. Les actions perte/vol/remplacement ne s’appliquent qu’aux cartes vendues.',
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

class _CardCard extends StatelessWidget {
  const _CardCard({required this.card});
  final CardLookup card;

  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      color: AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.maskedInternalCardNumber ?? 'Carte',
                          style:
                              AppText.mono(size: 16, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(card.cardType.frLabel,
                          style:
                              AppText.ui(size: 12.5, color: AppColors.inkMid)),
                    ],
                  ),
                ),
                CardStatusPill(status: card.status),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          DetailRow(label: 'UID NFC', value: card.nfcUid, mono: true),
          if (card.customerFullName != null)
            DetailRow(label: 'Titulaire', value: card.customerFullName!),
          if (card.customerPhoneMasked != null)
            DetailRow(
                label: 'Téléphone',
                value: card.customerPhoneMasked!,
                mono: true),
          DetailRow(
              label: 'Statut',
              value: card.status.frLabel,
              last: true),
        ],
      ),
    );
  }
}
