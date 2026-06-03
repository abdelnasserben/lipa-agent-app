import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/card.dart';
import '../agent/agent_providers.dart';
import 'card_lookup_screen.dart';
import 'card_sale_screen.dart';

/// Cards tab: the agent's assigned card stock + entry points to sell / look up.
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(cardStockProvider);
    final profile = ref.watch(profileProvider);
    final canSell =
        profile.maybeWhen(data: (p) => p.canSellCards, orElse: () => false);

    return Column(
      children: [
        ScreenHeader(
          title: 'Cartes',
          subtitle: 'Stock attribué',
          action: CircleButton(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CardLookupScreen()),
            ),
            child: const Icon(Icons.search_rounded),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cardStockProvider);
              await ref.read(cardStockProvider.future);
            },
            child: stock.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brand)),
              error: (_, _) => ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ErrorRetry(message: 'Stock indisponible.'),
                ),
              ]),
              data: (items) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (canSell) ...[
                    LipaButton(
                      label: 'Vendre une carte',
                      icon: const Icon(Icons.add_card_rounded),
                      size: BtnSize.lg,
                      full: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CardSaleScreen()),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cartes disponibles',
                          style:
                              AppText.ui(size: 14.5, weight: FontWeight.w700)),
                      Text('${items.length}',
                          style: AppText.mono(
                              size: 14,
                              weight: FontWeight.w600,
                              color: AppColors.inkMid)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Stock vide',
                      message:
                          'Aucune carte attribuée. Contactez le back-office pour un réapprovisionnement.',
                    )
                  else
                    for (final c in items) _StockRow(item: c),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});
  final CardStockItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LipaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top line: icon + full card number (own row so the 16-digit number
            // never wraps or competes with the batch chip for horizontal space).
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      color: AppColors.ink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.internalCardNumber,
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.mono(size: 15, weight: FontWeight.w600),
                    ),
                  ),
                ),
                if (item.batchRef.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _BatchChip(batchRef: item.batchRef),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Secondary line: UID (wraps to a 2nd line rather than truncating)
            // and the assignment date, dimmed.
            Text(
              'UID ${item.nfcUid}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(size: 12, color: AppColors.inkLow),
            ),
            if (item.assignedAt != null) ...[
              const SizedBox(height: 2),
              Text('Attribuée le ${fmtDateFr(item.assignedAt!)}',
                  style: AppText.ui(size: 11.5, color: AppColors.inkLow)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact `Lot <ref>` pill shown in the card-number row. Constrained so a long
/// batch reference truncates inside the chip instead of pushing the card number
/// off-screen.
class _BatchChip extends StatelessWidget {
  const _BatchChip({required this.batchRef});
  final String batchRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Lot $batchRef',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.ui(
            size: 11, weight: FontWeight.w600, color: AppColors.inkMid),
      ),
    );
  }
}
