import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/amount_input.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/party_card.dart';
import '../../core/widgets/result_screen.dart';
import '../../data/models/card.dart';
import '../../data/models/enums.dart';
import '../../data/models/lookup.dart';
import '../../data/repositories/agent_repository.dart';
import '../agent/agent_providers.dart';

/// Card sale (spec §5.6): confirm the customer, scan the card from assigned
/// stock, declare a price, sell. Always shows the price returned by the API
/// (config-driven pricing — spec §6.5).
class CardSaleScreen extends ConsumerStatefulWidget {
  const CardSaleScreen({super.key});

  @override
  ConsumerState<CardSaleScreen> createState() => _CardSaleScreenState();
}

class _CardSaleScreenState extends ConsumerState<CardSaleScreen> {
  final _phone = TextEditingController();
  final _idempotencyKey = newIdempotencyKey();

  CustomerLookup? _customer;
  String? _nfcUid;
  int _price = 0;
  bool _busy = false;
  String? _error;
  CardSaleResult? _result;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(agentRepositoryProvider).lookupCustomer(
            phoneCountryCode: '269',
            phoneNumber: _phone.text.replaceAll(RegExp(r'\D'), ''),
          );
      setState(() => _customer = c);
    } on ApiError catch (e) {
      setState(() => _error = frenchMessageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final uid = await ref.read(cardScannerProvider).scanCardUid(context);
    if (uid != null) setState(() => _nfcUid = uid);
  }

  Future<void> _sell() async {
    final customer = _customer;
    final uid = _nfcUid;
    if (customer == null || uid == null || _price <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(agentRepositoryProvider).sellCard(
            idempotencyKey: _idempotencyKey,
            customerId: customer.customerId,
            nfcUid: uid,
            cardPrice: _price,
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
        title: 'Vente de carte',
        headline: 'Carte vendue',
        subtitle:
            'Carte activée pour ${_customer?.fullName ?? 'le client'}.',
        replayed: _result!.replayed,
        onDone: () => Navigator.of(context).pop(),
        detail: LipaCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                  label: 'Prix facturé',
                  value: fmtKmf(_result!.cardPrice),
                  mono: true,
                  valueColor: AppColors.brandDeep),
              if (_result!.commissionAmount > 0)
                DetailRow(
                    label: 'Commission',
                    value: fmtKmf(_result!.commissionAmount),
                    mono: true),
              DetailRow(
                  label: 'Réf.',
                  value: shortId(_result!.transactionId),
                  mono: true,
                  last: true),
            ],
          ),
        ),
      );
    }

    final canSell = _customer != null && _nfcUid != null && _price > 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Vendre une carte',
              subtitle: 'Depuis votre stock',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Step 1 — customer.
                  const _StepLabel(n: 1, text: 'Client'),
                  const SizedBox(height: 10),
                  if (_customer == null) ...[
                    PhoneInput(
                        controller: _phone,
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 10),
                    LipaButton(
                      label: 'Rechercher le client',
                      variant: BtnVariant.secondary,
                      full: true,
                      loading: _busy && _customer == null,
                      onPressed:
                          PhoneValidator.isComplete(_phone.text) ? _lookup : null,
                    ),
                  ] else
                    PartyCard(
                      name: _customer!.fullName,
                      subtitle: _customer!.phonePretty,
                      statusLabel: _customer!.status.frLabel,
                      statusActive: _customer!.status == CustomerStatus.active,
                      trailing: IconButton(
                        onPressed: () => setState(() => _customer = null),
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.inkMid),
                      ),
                    ),
                  const SizedBox(height: 22),

                  // Step 2 — card.
                  const _StepLabel(n: 2, text: 'Carte (NFC)'),
                  const SizedBox(height: 10),
                  _CardSlot(uid: _nfcUid, onScan: _scan),
                  const SizedBox(height: 22),

                  // Step 3 — price.
                  const _StepLabel(n: 3, text: 'Prix de la carte'),
                  const SizedBox(height: 14),
                  AmountInput(
                    autofocus: false,
                    quickAmounts: const [1000, 2500, 5000, 10000],
                    onChanged: (v) => setState(() => _price = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: AppText.ui(size: 13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  LipaButton(
                    label: _price > 0
                        ? 'Vendre pour ${fmtKmf(_price)}'
                        : 'Vendre la carte',
                    size: BtnSize.lg,
                    full: true,
                    loading: _busy && _result == null && _customer != null,
                    onPressed: canSell ? _sell : null,
                  ),
                  const SizedBox(height: 8),
                  Text('Le prix final peut être ajusté par configuration.',
                      textAlign: TextAlign.center,
                      style:
                          AppText.ui(size: 12, color: AppColors.inkLow)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.n, required this.text});
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.nearBlack, shape: BoxShape.circle),
          child: Text('$n',
              style: AppText.mono(
                  size: 12, weight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Text(text, style: AppText.ui(size: 14.5, weight: FontWeight.w700)),
      ],
    );
  }
}

class _CardSlot extends StatelessWidget {
  const _CardSlot({required this.uid, required this.onScan});
  final String? uid;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return LipaButton(
        label: 'Scanner la carte',
        icon: const Icon(Icons.nfc_rounded),
        variant: BtnVariant.secondary,
        size: BtnSize.lg,
        full: true,
        onPressed: onScan,
      );
    }
    return LipaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, color: AppColors.brandDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Carte sélectionnée',
                    style: AppText.ui(size: 12.5, color: AppColors.inkMid)),
                Text(uid!,
                    style: AppText.mono(size: 14, weight: FontWeight.w600)),
              ],
            ),
          ),
          TextButton(onPressed: onScan, child: const Text('Changer')),
        ],
      ),
    );
  }
}
