import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/result_screen.dart';
import '../../data/models/enrollment.dart';
import 'enroll_controller.dart';
import 'kyc_documents_screen.dart';

/// Customer enrollment (spec §5.5): create the customer + wallet, then offer to
/// upload KYC documents. National-ID type is a small fixed picker matching the
/// `KycDocumentType` family the back-office reviews.
class EnrollScreen extends ConsumerStatefulWidget {
  const EnrollScreen({super.key});

  @override
  ConsumerState<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends ConsumerState<EnrollScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _island = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();

  DateTime? _dob;
  String _idType = 'CNI';

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _island.dispose();
    _city.dispose();
    _district.dispose();
    super.dispose();
  }

  bool get _valid =>
      _fullName.text.trim().isNotEmpty &&
      _dob != null &&
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 4 &&
      _idNumber.text.trim().isNotEmpty;

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    final form = EnrollCustomerForm(
      fullName: _fullName.text.trim(),
      dateOfBirth: _isoDate(_dob!),
      phoneCountryCode: '269',
      phoneNumber: _phone.text.replaceAll(RegExp(r'\D'), ''),
      nationalIdNumber: _idNumber.text.trim(),
      nationalIdType: _idType,
      addressIsland: _island.text.trim(),
      addressCity: _city.text.trim(),
      addressDistrict: _district.text.trim(),
    );
    ref.read(enrollControllerProvider.notifier).submit(form);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(enrollControllerProvider);

    if (state.step == EnrollStep.done && state.result != null) {
      return _DoneScreen(result: state.result!, name: _fullName.text.trim());
    }

    final submitting = state.step == EnrollStep.submitting;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Enrôler un client',
              subtitle: 'Nouveau compte + KYC',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const FieldLabel('Nom complet'),
                  const SizedBox(height: 8),
                  BoxedTextField(
                    controller: _fullName,
                    hintText: 'Prénom et nom',
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Date de naissance'),
                  const SizedBox(height: 8),
                  _DateField(value: _dob, onTap: _pickDob),
                  const SizedBox(height: 18),
                  const FieldLabel('Numéro de téléphone'),
                  const SizedBox(height: 8),
                  PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 18),
                  const FieldLabel('Type de pièce'),
                  const SizedBox(height: 8),
                  _IdTypePicker(
                    value: _idType,
                    onChanged: (v) => setState(() => _idType = v),
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Numéro de pièce'),
                  const SizedBox(height: 8),
                  BoxedTextField(
                    controller: _idNumber,
                    hintText: 'N° de la pièce d’identité',
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 22),
                  Text('Adresse (facultatif)',
                      style: AppText.ui(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: AppColors.inkLow)),
                  const SizedBox(height: 12),
                  BoxedTextField(controller: _island, hintText: 'Île'),
                  const SizedBox(height: 10),
                  BoxedTextField(controller: _city, hintText: 'Ville'),
                  const SizedBox(height: 10),
                  BoxedTextField(controller: _district, hintText: 'Quartier'),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(state.errorMessage!,
                        style: AppText.ui(size: 13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 22),
                  LipaButton(
                    label: 'Créer le compte client',
                    size: BtnSize.lg,
                    full: true,
                    loading: submitting,
                    onPressed: _valid ? _submit : null,
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

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.inkMid),
            const SizedBox(width: 12),
            Text(
              value == null
                  ? 'Sélectionner une date'
                  : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
              style: AppText.ui(
                  size: 15,
                  color: value == null ? AppColors.inkFaint : AppColors.inkHi),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdTypePicker extends StatelessWidget {
  const _IdTypePicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _types = [
    ('CNI', 'Carte nationale'),
    ('PASSPORT', 'Passeport'),
    ('OTHER', 'Autre'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final (code, label) in _types)
          ChoiceChip(
            label: Text(label),
            selected: value == code,
            onSelected: (_) => onChanged(code),
            labelStyle: AppText.ui(
                size: 13,
                weight: FontWeight.w600,
                color: value == code ? Colors.white : AppColors.inkHi),
            selectedColor: AppColors.brand,
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(
                  color: value == code ? AppColors.brand : AppColors.borderHi),
            ),
          ),
      ],
    );
  }
}

class _DoneScreen extends StatelessWidget {
  const _DoneScreen({required this.result, required this.name});
  final EnrollCustomerResult result;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ResultScreen(
      title: 'Enrôlement',
      headline: 'Client enrôlé',
      subtitle:
          '$name a été créé avec un portefeuille actif. Ajoutez ses pièces KYC maintenant.',
      onDone: () => Navigator.of(context).pop(),
      secondaryLabel: 'Ajouter des documents KYC',
      onSecondary: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => KycDocumentsScreen(
              customerId: result.customerId, customerName: name),
        ),
      ),
      detail: LipaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _CopyRow(label: 'Référence client', value: result.externalRef),
            _CopyRow(label: 'ID client', value: result.customerId),
            _CopyRow(label: 'Portefeuille', value: result.walletId, last: true),
          ],
        ),
      ),
    );
  }
}

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
            content:
                Text('$label copié', style: AppText.ui(color: Colors.white)),
            backgroundColor: AppColors.nearBlack,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: DetailRow(label: label, value: value, mono: true, copy: true, last: last),
    );
  }
}
