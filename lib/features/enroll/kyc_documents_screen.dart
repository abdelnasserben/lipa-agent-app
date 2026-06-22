import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agent_repository.dart';

/// KYC documents for a customer (spec §5.5): list + capture/pick + upload.
/// The capture goes through `image_picker` (camera or gallery), the only
/// hardware-facing dependency in this build.
class KycDocumentsScreen extends ConsumerStatefulWidget {
  const KycDocumentsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  ConsumerState<KycDocumentsScreen> createState() =>
      _KycDocumentsScreenState();
}

/// Largest dimension we capture/keep for a KYC photo. An ID document stays
/// perfectly legible at this size, and it keeps the file well under the 10 MB
/// server cap — full-resolution camera shots otherwise time out on upload and
/// surface as a misleading "network" error.
const int _kMaxImageDimension = 1600;

/// Client-side mirror of the server's 10 MB cap (spec §5.5), so we fail fast
/// with a clear message instead of after a long upload.
const int _kMaxFileBytes = 10 * 1024 * 1024;

class _KycDocumentsScreenState extends ConsumerState<KycDocumentsScreen> {
  late Future<List<KycDocument>> _future;
  bool _uploading = false;
  KycDocumentType _selectedType = KycDocumentType.nationalId;

  // A captured-but-not-yet-sent document, held for confirmation/preview.
  Uint8List? _pendingBytes;
  String? _pendingName;
  String? _pendingMime;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(agentRepositoryProvider)
        .getKycDocuments(widget.customerId);
  }

  void _reload() {
    setState(() {
      _future =
          ref.read(agentRepositoryProvider).getKycDocuments(widget.customerId);
    });
  }

  /// Pick/capture an image and stage it for confirmation — does NOT upload yet.
  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: _kMaxImageDimension.toDouble(),
      maxHeight: _kMaxImageDimension.toDouble(),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _kMaxFileBytes) {
      _snack('Image trop volumineuse (10 Mo maximum).', error: true);
      return;
    }
    setState(() {
      _pendingBytes = bytes;
      _pendingName = picked.name;
      _pendingMime = picked.mimeType;
    });
  }

  void _discardPending() {
    setState(() {
      _pendingBytes = null;
      _pendingName = null;
      _pendingMime = null;
    });
  }

  /// Upload the staged document after the agent confirms.
  Future<void> _confirmUpload() async {
    final bytes = _pendingBytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(agentRepositoryProvider).uploadKycDocument(
            customerId: widget.customerId,
            documentType: _selectedType,
            file: KycUploadFile(
              bytes: bytes,
              filename: _pendingName ?? 'document.jpg',
              contentType: _pendingMime,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document envoyé',
              style: AppText.ui(color: Colors.white)),
          backgroundColor: AppColors.brandDeep,
          duration: const Duration(seconds: 1),
        ),
      );
      _discardPending();
      _reload();
    } on ApiError catch (e) {
      if (mounted) _snack(frenchMessageForError(e), error: true);
    } catch (_) {
      if (mounted) _snack('Échec de l’envoi.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppText.ui(color: Colors.white)),
      backgroundColor: error ? AppColors.danger : AppColors.nearBlack,
    ));
  }

  void _pickSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.inkHi),
              title: Text('Prendre une photo', style: AppText.ui(size: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.inkHi),
              title: Text('Choisir dans la galerie',
                  style: AppText.ui(size: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Documents KYC',
              subtitle: widget.customerName,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const FieldHint('Type de document à envoyer'),
                  const SizedBox(height: 10),
                  _TypePicker(
                    value: _selectedType,
                    onChanged: (t) => setState(() => _selectedType = t),
                  ),
                  const SizedBox(height: 14),
                  if (_pendingBytes == null) ...[
                    LipaButton(
                      label: 'Ajouter un document',
                      icon: const Icon(Icons.upload_file_rounded),
                      size: BtnSize.lg,
                      full: true,
                      onPressed: _pickSource,
                    ),
                    const SizedBox(height: 8),
                    Text('Image, 10 Mo maximum.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(size: 12, color: AppColors.inkLow)),
                  ] else
                    _PendingPreview(
                      bytes: _pendingBytes!,
                      typeLabel: _selectedType.frLabel,
                      uploading: _uploading,
                      onConfirm: _confirmUpload,
                      onDiscard: _uploading ? null : _discardPending,
                    ),
                  const SizedBox(height: 24),
                  Text('Documents déjà envoyés',
                      style: AppText.ui(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  FutureBuilder<List<KycDocument>>(
                    future: _future,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.brand),
                          ),
                        );
                      }
                      final docs = snap.data ?? const [];
                      if (docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.folder_open_rounded,
                          title: 'Aucun document',
                          message:
                              'Ajoutez la pièce d’identité du client et tout justificatif requis.',
                        );
                      }
                      return Column(
                        children: [
                          for (final d in docs) _DocRow(doc: d),
                        ],
                      );
                    },
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

class FieldHint extends StatelessWidget {
  const FieldHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.ui(size: 13, weight: FontWeight.w600));
}

/// Preview of a captured-but-unsent document, with explicit confirm/discard so
/// the upload only happens after the agent reviews the image.
class _PendingPreview extends StatelessWidget {
  const _PendingPreview({
    required this.bytes,
    required this.typeLabel,
    required this.uploading,
    required this.onConfirm,
    required this.onDiscard,
  });

  final Uint8List bytes;
  final String typeLabel;
  final bool uploading;
  final VoidCallback onConfirm;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vérifiez le document — $typeLabel',
              style: AppText.ui(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LipaButton(
            label: 'Confirmer l’envoi',
            icon: const Icon(Icons.cloud_upload_outlined),
            size: BtnSize.lg,
            full: true,
            loading: uploading,
            onPressed: uploading ? null : onConfirm,
          ),
          const SizedBox(height: 8),
          LipaButton(
            label: 'Reprendre',
            variant: BtnVariant.ghost,
            full: true,
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.value, required this.onChanged});
  final KycDocumentType value;
  final ValueChanged<KycDocumentType> onChanged;

  static const _types = [
    KycDocumentType.nationalId,
    KycDocumentType.passport,
    KycDocumentType.proofOfAddress,
    KycDocumentType.other,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in _types)
          ChoiceChip(
            label: Text(t.frLabel),
            selected: value == t,
            onSelected: (_) => onChanged(t),
            labelStyle: AppText.ui(
                size: 12.5,
                weight: FontWeight.w600,
                color: value == t ? Colors.white : AppColors.inkHi),
            selectedColor: AppColors.brand,
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(
                  color: value == t ? AppColors.brand : AppColors.borderHi),
            ),
          ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});
  final KycDocument doc;

  @override
  Widget build(BuildContext context) {
    final (pillKind, pillLabel) = switch (doc.status) {
      KycDocumentStatus.accepted => (PillKind.success, 'Acceptée'),
      KycDocumentStatus.rejected => (PillKind.declined, 'Rejetée'),
      _ => (PillKind.pending, 'En revue'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LipaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              child: const Icon(Icons.description_outlined,
                  size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.documentType.frLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    doc.uploadedAt != null
                        ? fmtDateTimeFr(doc.uploadedAt!)
                        : '—',
                    style: AppText.ui(size: 12, color: AppColors.inkLow),
                  ),
                ],
              ),
            ),
            StatusPill(label: pillLabel, kind: pillKind),
          ],
        ),
      ),
    );
  }
}
