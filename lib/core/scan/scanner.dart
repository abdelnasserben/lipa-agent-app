import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';

/// Hardware-scan seam.
///
/// Every card flow (lookup, sale, replacement) reads a card NFC UID through
/// this interface. The active implementation is [NfcCardScanner]: it uses a
/// real NFC reader where the device has one, and falls back to manual UID entry
/// where it doesn't — so agents on non-NFC phones (or whose chip is damaged /
/// can't read a given card) are never blocked.
///
/// A returned `null` means the operator cancelled.
abstract class CardScanner {
  /// Reads a card NFC UID (14 hex chars, spec §5.4). Returns the normalized
  /// lowercase hex, or null if cancelled.
  Future<String?> scanCardUid(BuildContext context);
}

/// Manual-entry scanner: opens a sheet validating a 14-hex UID. Used directly
/// on devices without NFC, and as the opt-in fallback inside [NfcCardScanner].
class ManualEntryCardScanner implements CardScanner {
  const ManualEntryCardScanner();

  @override
  Future<String?> scanCardUid(BuildContext context) => promptManualUid(context);
}

/// Opens the manual UID-entry sheet. Shared by the manual scanner and the NFC
/// scanner's "saisir l'UID" fallback.
Future<String?> promptManualUid(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _UidEntrySheet(),
  );
}

/// Real NFC scanner.
///
/// On `scanCardUid`:
///  - If the device has no usable NFC reader, goes straight to manual entry
///    (the agent can read the UID elsewhere — no penalty).
///  - Otherwise shows an NFC prompt sheet. The agent taps the card to read it,
///    or taps "Saisir l'UID manuellement" to fall back (damaged chip, a card
///    the reader won't pick up, etc.).
class NfcCardScanner implements CardScanner {
  const NfcCardScanner();

  @override
  Future<String?> scanCardUid(BuildContext context) async {
    NfcAvailability availability;
    try {
      availability = await NfcManager.instance.checkAvailability();
    } catch (_) {
      availability = NfcAvailability.unsupported;
    }
    if (!context.mounted) return null;
    if (availability != NfcAvailability.enabled) {
      // No usable NFC reader (unsupported or disabled) → manual entry only.
      return promptManualUid(context);
    }
    final result = await showModalBottomSheet<_NfcSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _NfcScanSheet(),
    );
    if (result == null || result.cancelled) return null;
    if (result.switchToManual) {
      // Agent opted out of NFC (damaged chip / unreadable card) → manual entry.
      if (!context.mounted) return null;
      return promptManualUid(context);
    }
    return result.uid;
  }
}

/// Outcome of the NFC scan sheet: a read [uid], a request to [switchToManual],
/// or a plain [cancelled] dismissal.
class _NfcSheetResult {
  const _NfcSheetResult({this.uid, this.switchToManual = false})
      : cancelled = uid == null && !switchToManual;
  final String? uid;
  final bool switchToManual;
  final bool cancelled;
}

/// Validates the 14-hex NFC UID and normalizes to lowercase. The backend
/// accepts either case (spec §7.4) — we send a consistent lowercase value.
bool isValidNfcUid(String raw) {
  final v = raw.trim();
  return RegExp(r'^[0-9a-fA-F]{14}$').hasMatch(v);
}

/// Pulls the tag UID out of the discovered tag as lowercase hex. On Android the
/// base tag carries the `id` directly; on iOS we read it from whichever tag
/// tech is present (MiFare / FeliCa / ISO15693). Returns null if none found.
String? nfcUidFromTag(NfcTag tag) {
  final id = NfcTagAndroid.from(tag)?.id ??
      MiFareIos.from(tag)?.identifier ??
      FeliCaIos.from(tag)?.currentIDm ??
      Iso15693Ios.from(tag)?.identifier;
  if (id == null || id.isEmpty) return null;
  return _hex(id);
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// NFC tap-to-read sheet. Starts a reader session on open, reports the read UID
/// (or a transient error), and offers a manual-entry fallback link.
class _NfcScanSheet extends StatefulWidget {
  const _NfcScanSheet();

  @override
  State<_NfcScanSheet> createState() => _NfcScanSheetState();
}

class _NfcScanSheetState extends State<_NfcScanSheet> {
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    try {
      await NfcManager.instance.startSession(
        // The card is ISO14443 (MIFARE) per spec §5.4; poll all so the session
        // opens on either platform — reading is driven by the tag tech.
        pollingOptions: NfcPollingOption.values.toSet(),
        alertMessageIos: 'Approchez la carte du téléphone',
        onDiscovered: (tag) async {
          final uid = nfcUidFromTag(tag);
          if (uid != null && isValidNfcUid(uid)) {
            await _stop();
            if (mounted) {
              _done = true;
              Navigator.of(context).pop(_NfcSheetResult(uid: uid));
            }
          } else {
            // Read something, but not a UID we recognize — keep the session
            // open and let the agent retry or switch to manual entry.
            if (mounted) {
              setState(() => _error =
                  'Carte non reconnue. Réessayez ou saisissez l’UID.');
            }
          }
        },
        onSessionErrorIos: (e) {
          if (mounted) {
            setState(() => _error = 'Lecture NFC interrompue. Réessayez.');
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Le lecteur NFC est indisponible.');
      }
    }
  }

  Future<void> _stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Session may already be closed; ignore.
    }
  }

  Future<void> _switchToManual() async {
    await _stop();
    if (!mounted) return;
    // Close the NFC sheet; the scanner opens manual entry next.
    _done = true;
    Navigator.of(context)
        .pop(const _NfcSheetResult(switchToManual: true));
  }

  @override
  void dispose() {
    if (!_done) _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D2C5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Scanner la carte',
                    style: AppText.ui(size: 18, weight: FontWeight.w700)),
              ),
              CircleButton(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nfc_rounded,
                  size: 44, color: AppColors.brandDeep),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Approchez la carte du dos du téléphone pour la lire.',
            textAlign: TextAlign.center,
            style: AppText.ui(size: 14, color: AppColors.inkMid, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InfoBanner(
              kind: PillKind.declined,
              icon: Icons.error_outline,
              text: _error!,
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _switchToManual,
              child: Text('Saisir l’UID manuellement',
                  style: AppText.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.brandDeep)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UidEntrySheet extends StatefulWidget {
  const _UidEntrySheet();

  @override
  State<_UidEntrySheet> createState() => _UidEntrySheetState();
}

class _UidEntrySheetState extends State<_UidEntrySheet> {
  final _controller = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final valid = isValidNfcUid(value);
    final showError = _touched && value.isNotEmpty && !valid;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D2C5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Saisir l’UID',
                    style: AppText.ui(size: 18, weight: FontWeight.w700)),
              ),
              CircleButton(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saisissez l’identifiant (UID) de la carte à 14 caractères hexadécimaux.',
            style: AppText.ui(size: 13, color: AppColors.inkMid, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 14,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => _touched = true),
            style: AppText.mono(size: 18, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '04A1B2C3D4E5F6',
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                    color: showError ? AppColors.danger : AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                    color: showError ? AppColors.danger : AppColors.brand,
                    width: 1.5),
              ),
            ),
          ),
          if (showError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('UID invalide : 14 caractères hex attendus.',
                  style: AppText.ui(size: 12, color: AppColors.danger)),
            ),
          const SizedBox(height: 14),
          LipaButton(
            label: 'Confirmer',
            size: BtnSize.lg,
            full: true,
            onPressed: valid
                ? () => Navigator.of(context).pop(value.toLowerCase())
                : null,
          ),
        ],
      ),
    );
  }
}
