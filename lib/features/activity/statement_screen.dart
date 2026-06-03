import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/transaction_receipt.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';
import '../agent/agent_providers.dart';

/// Wallet ledger statement (spec §5.3) — a date window + the ledger entries
/// with their running balance, filterable by date and downloadable as PDF
/// (mirrors the Lipa customer statement screen).
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key});

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final statements = ref.watch(statementsProvider(_range));
    final loaded = statements.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Relevé',
              subtitle: 'Écritures du portefeuille',
              onBack: () => Navigator.of(context).pop(),
              action: CircleButton(
                onTap: (loaded == null || loaded.isEmpty)
                    ? null
                    : () => _downloadPdf(loaded),
                child: Icon(
                  Icons.download,
                  size: 20,
                  color: (loaded == null || loaded.isEmpty)
                      ? AppColors.inkLow
                      : AppColors.inkHi,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickRange,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderHi),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: AppColors.inkMid),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _range == null
                                    ? 'Toute la période'
                                    : '${_fmt(_range!.start)} – ${_fmt(_range!.end)}',
                                style: AppText.ui(size: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_range != null) ...[
                    const SizedBox(width: 8),
                    CircleButton(
                      onTap: () => setState(() => _range = null),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(statementsProvider(_range));
                  await ref.read(statementsProvider(_range).future);
                },
                child: statements.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand)),
                  error: (_, _) => ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: ErrorRetry(message: 'Relevé indisponible.'),
                    ),
                  ]),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return ListView(children: const [
                        EmptyState(
                          icon: Icons.description_outlined,
                          title: 'Relevé vide',
                          message: 'Aucune écriture pour cette période.',
                        ),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _EntryRow(entry: entries[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('dd/MM', 'fr_FR').format(d);

  /// Generates the statement PDF for the currently-loaded entries and opens
  /// the system print/preview sheet (save/share from there).
  Future<void> _downloadPdf(List<StatementEntry> entries) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => statementPdfBytes(
          entries,
          from: _range?.start,
          to: _range?.end,
        ),
        name: 'releve-lipa.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le relevé PDF.')),
      );
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final StatementEntry entry;

  @override
  Widget build(BuildContext context) {
    final credit = entry.entryType.isCredit;
    return LipaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: credit ? AppColors.brandSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              credit ? Icons.add_rounded : Icons.remove_rounded,
              size: 20,
              color: credit ? AppColors.brandDeep : AppColors.inkMid,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.descriptionFr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  entry.postedAt != null ? fmtDateTimeFr(entry.postedAt!) : '—',
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
                fmtKmf(entry.signedAmount, signed: credit),
                style: AppText.mono(
                    size: 14,
                    weight: FontWeight.w600,
                    color: credit ? AppColors.brandDeep : AppColors.inkHi),
              ),
              const SizedBox(height: 2),
              Text('Solde ${fmtKmfNoUnit(entry.runningBalance)}',
                  style: AppText.mono(size: 11, color: AppColors.inkLow)),
            ],
          ),
        ],
      ),
    );
  }
}
