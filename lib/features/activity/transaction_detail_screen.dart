import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/transaction_receipt.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/transaction.dart';
import '../agent/agent_providers.dart';

/// Full transaction detail (spec §5.3). Fetched fresh by id so the screen is
/// linkable from anywhere (dashboard, activity, receipts).
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.txId});
  final String txId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(transactionProvider(txId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Détail de l’opération',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: tx.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: ErrorRetry(message: 'Transaction introuvable.'),
                ),
                data: (t) => _Body(tx: t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tx});
  final AgentTransaction tx;

  @override
  Widget build(BuildContext context) {
    final incoming = tx.incoming;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Amount hero.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TxStatusPill(status: tx.status),
              const SizedBox(height: 14),
              Text(
                fmtKmf(tx.signedAmount, signed: incoming),
                style: AppText.mono(
                    size: 32,
                    weight: FontWeight.w600,
                    color: incoming ? AppColors.brandDeep : AppColors.inkHi),
              ),
              const SizedBox(height: 6),
              Text(tx.type.frLabel,
                  style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(label: 'Type', value: tx.type.frLabel),
              if (tx.completedAt != null)
                DetailRow(
                    label: 'Effectué le',
                    value: fmtDateTimeFr(tx.completedAt!)),
              if (tx.declinedAt != null)
                DetailRow(
                    label: 'Refusé le', value: fmtDateTimeFr(tx.declinedAt!)),
              if (tx.createdAt != null)
                DetailRow(
                    label: 'Créé le', value: fmtDateTimeFr(tx.createdAt!)),
              DetailRow(
                  label: 'Montant',
                  value: fmtKmf(tx.requestedAmount),
                  mono: true),
              if (tx.feeAmount > 0)
                DetailRow(
                    label: 'Frais', value: fmtKmf(tx.feeAmount), mono: true),
              if (tx.commissionAmount > 0)
                DetailRow(
                    label: 'Commission',
                    value: fmtKmf(tx.commissionAmount),
                    mono: true,
                    valueColor: AppColors.brandDeep),
              DetailRow(
                  label: 'Net destinataire',
                  value: fmtKmf(tx.netAmountToDestination),
                  mono: true),
              if (tx.declineReason != null)
                DetailRow(
                    label: 'Motif du refus',
                    value: tx.declineReason!,
                    valueColor: AppColors.danger),
              DetailRow(label: 'Initiateur', value: tx.initiatorType),
              _CopyRow(label: 'Réf. transaction', value: tx.id),
              if (tx.correlationId != null)
                _CopyRow(
                    label: 'Corrélation', value: tx.correlationId!, last: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: LipaButton(
                label: 'Reçu PDF',
                variant: BtnVariant.secondary,
                icon: const Icon(Icons.download),
                onPressed: () => _openReceiptPdf(context, tx),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LipaButton(
                label: 'Partager',
                variant: BtnVariant.secondary,
                icon: const Icon(Icons.share),
                onPressed: () => _shareReceipt(context, tx),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Generates the receipt PDF locally and opens the system print/preview
  /// sheet, from which the user can save or share the file.
  Future<void> _openReceiptPdf(BuildContext context, AgentTransaction t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => receiptPdfBytes(t),
        name: 'recu-lipa-${t.id}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le reçu PDF.')),
      );
    }
  }

  /// Opens the native share sheet with a plain-text recap of the transaction.
  Future<void> _shareReceipt(BuildContext context, AgentTransaction t) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      receiptShareText(t),
      subject: 'Reçu Lipa',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }
}

/// A DetailRow that copies its value to the clipboard on tap.
class _CopyRow extends StatelessWidget {
  const _CopyRow(
      {required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copié', style: AppText.ui(color: Colors.white)),
            backgroundColor: AppColors.nearBlack,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: DetailRow(
          label: label, value: shortId(value), mono: true, copy: true, last: last),
    );
  }
}
