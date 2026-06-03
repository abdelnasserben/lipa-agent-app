import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/transaction.dart';

/// A single transaction row (icon, type+time, signed amount + status dot).
/// Direction is derived from the agent wallet (incoming = credited).
class TxRow extends StatelessWidget {
  const TxRow({
    super.key,
    required this.tx,
    this.divider = false,
    this.onTap,
  });

  final AgentTransaction tx;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final incoming = tx.incoming;
    final (icon, label) = _present(tx.type, incoming);
    final at = tx.effectiveAt;
    final amountColor = tx.status.isDeclined
        ? AppColors.inkLow
        : (incoming ? AppColors.brandDeep : AppColors.inkHi);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 19, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    at != null ? fmtRelativeFr(at) : '—',
                    style: AppText.ui(size: 12, color: AppColors.inkLow),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtKmf(tx.signedAmount, signed: incoming),
                  style: AppText.mono(
                      size: 14, weight: FontWeight.w600, color: amountColor),
                ),
                const SizedBox(height: 3),
                _StatusDot(status: tx.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String) _present(TransactionType type, bool incoming) {
    return switch (type) {
      TransactionType.cashIn => (Icons.south_west_rounded, 'Dépôt client'),
      TransactionType.cashOut => (Icons.north_east_rounded, 'Retrait marchand'),
      TransactionType.cardSale => (Icons.credit_card_rounded, 'Vente de carte'),
      TransactionType.cardReplacement =>
        (Icons.sync_rounded, 'Remplacement de carte'),
      TransactionType.commissionPayout =>
        (Icons.savings_outlined, 'Commission'),
      TransactionType.agentFundIn =>
        (Icons.account_balance_wallet_outlined, 'Approvisionnement'),
      _ => (Icons.swap_horiz_rounded, type.frLabel),
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      TransactionStatus.completed => (AppColors.brand, 'Effectué'),
      TransactionStatus.pending => (AppColors.pending, 'En attente'),
      TransactionStatus.authorized => (AppColors.info, 'Autorisé'),
      TransactionStatus.declined => (AppColors.danger, 'Refusé'),
      TransactionStatus.expired => (AppColors.inkLow, 'Expiré'),
      TransactionStatus.reversed => (AppColors.warn, 'Annulé'),
      TransactionStatus.unknown => (AppColors.inkLow, '—'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.ui(size: 11.5, color: AppColors.inkMid)),
      ],
    );
  }
}
