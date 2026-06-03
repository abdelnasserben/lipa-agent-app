import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/amount_input.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/result_screen.dart';
import '../../data/models/card.dart';
import '../../data/models/lookup.dart';
import '../../data/repositories/agent_repository.dart';
import '../agent/agent_providers.dart';

/// Card replacement (spec §5.6): pick a card from assigned stock, declare a
/// fee, replace the customer's reported card. Shows the fee returned by the API.
class CardReplaceScreen extends ConsumerStatefulWidget {
  const CardReplaceScreen({super.key, required this.card});
  final CardLookup card;

  @override
  ConsumerState<CardReplaceScreen> createState() => _CardReplaceScreenState();
}

class _CardReplaceScreenState extends ConsumerState<CardReplaceScreen> {
  final _idempotencyKey = newIdempotencyKey();
  CardStockItem? _stock;
  int _fee = 0;
  bool _busy = false;
  String? _error;
  CardReplacementResult? _result;

  Future<void> _replace() async {
    final stock = _stock;
    if (stock == null || _fee <= 0 || widget.card.customerId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(agentRepositoryProvider).replaceCard(
            idempotencyKey: _idempotencyKey,
            customerId: widget.card.customerId!,
            cardId: widget.card.cardId,
            stockId: stock.id,
            replacementFee: _fee,
          );
      ref.invalidate(balanceProvider);
      ref.invalidate(cardStockProvider);
      ref.invalidate(transactionsProvider);
      setState(() => _result = res);
    } on ApiError catch (e) {
      setState(() => _error = frenchMessageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ResultScreen(
        title: 'Remplacement',
        headline: 'Carte remplacée',
        subtitle: 'Nouvelle carte activée pour le client.',
        replayed: _result!.replayed,
        onDone: () => Navigator.of(context)
          ..pop()
          ..maybePop(),
        detail: LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (_result!.replacementFee != null)
                DetailRow(
                    label: 'Frais facturés',
                    value: fmtKmf(_result!.replacementFee!),
                    mono: true,
                    valueColor: AppColors.brandDeep),
              if ((_result!.commissionAmount ?? 0) > 0)
                DetailRow(
                    label: 'Commission',
                    value: fmtKmf(_result!.commissionAmount!),
                    mono: true),
              DetailRow(
                  label: 'Nouvelle carte',
                  value: shortId(_result!.newCardId),
                  mono: true),
              DetailRow(
                  label: 'Ancienne carte',
                  value: shortId(_result!.oldCardId),
                  mono: true,
                  last: true),
            ],
          ),
        ),
      );
    }

    final stockAsync = ref.watch(cardStockProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Remplacer la carte',
              subtitle: widget.card.maskedInternalCardNumber ?? '',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const InfoBanner(
                    icon: Icons.sync_rounded,
                    text:
                        'Choisissez une carte de votre stock attribué pour remplacer la carte du client.',
                  ),
                  const SizedBox(height: 18),
                  Text('Carte de remplacement',
                      style: AppText.ui(size: 14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  stockAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.brand)),
                    ),
                    error: (_, _) =>
                        const ErrorRetry(message: 'Stock indisponible.'),
                    data: (stock) {
                      if (stock.isEmpty) {
                        return const InfoBanner(
                          kind: PillKind.warn,
                          icon: Icons.inventory_2_outlined,
                          text:
                              'Aucune carte disponible dans votre stock attribué.',
                        );
                      }
                      return Column(
                        children: [
                          for (final s in stock)
                            _StockOption(
                              item: s,
                              selected: _stock?.id == s.id,
                              onTap: () => setState(() => _stock = s),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text('Frais de remplacement',
                      style: AppText.ui(size: 14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  AmountInput(
                    autofocus: false,
                    quickAmounts: const [500, 1000, 2000, 5000],
                    onChanged: (v) => setState(() => _fee = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: AppText.ui(size: 13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  LipaButton(
                    label: _fee > 0
                        ? 'Remplacer pour ${fmtKmf(_fee)}'
                        : 'Remplacer la carte',
                    size: BtnSize.lg,
                    full: true,
                    loading: _busy,
                    onPressed:
                        _stock != null && _fee > 0 ? _replace : null,
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

class _StockOption extends StatelessWidget {
  const _StockOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final CardStockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                  color: selected ? AppColors.brand : AppColors.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.brand : AppColors.inkLow,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.internalCardNumber,
                          style: AppText.mono(
                              size: 14, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('UID ${item.nfcUid} · ${item.batchRef}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(
                              size: 12, color: AppColors.inkLow)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
