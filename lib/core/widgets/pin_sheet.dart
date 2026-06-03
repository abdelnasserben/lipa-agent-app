import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'common.dart';

/// A bottom-sheet PIN entry pad (Lipa design: SendStepPin / Keypad).
///
/// Returns the entered PIN via [onSubmit]. The caller owns the submit logic
/// (it resubmits the financial request with the PIN). Shows [errorMessage]
/// inline (e.g. wrong PIN) without dismissing.
///
/// In the Agent app this is used for the cash-out **merchant** PIN gate
/// (spec §8): the merchant types their auth PIN on the agent device.
class PinSheet extends StatefulWidget {
  const PinSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.submitting = false,
    this.errorMessage,
  });

  final String title;
  final String subtitle;
  final ValueChanged<String> onSubmit;
  final bool submitting;
  final String? errorMessage;

  @override
  State<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<PinSheet> {
  String _pin = '';
  static const _max = 8;
  static const _min = 4;

  void _press(String key) {
    if (widget.submitting) return;
    setState(() {
      if (key == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < _max) {
        _pin += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                child: Text(widget.title,
                    style: AppText.ui(size: 18, weight: FontWeight.w700)),
              ),
              CircleButton(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.subtitle,
              style:
                  AppText.ui(size: 13.5, color: AppColors.inkMid, height: 1.5)),
          const SizedBox(height: 22),
          // Dots.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_max, (i) {
              final filled = i < _pin.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.brand : const Color(0xFFE5E2D8),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(widget.errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.ui(size: 13, color: AppColors.danger)),
          ],
          const SizedBox(height: 22),
          _Keypad(onPress: _press),
          const SizedBox(height: 8),
          LipaButton(
            label: 'Confirmer',
            size: BtnSize.lg,
            full: true,
            loading: widget.submitting,
            onPressed:
                _pin.length >= _min ? () => widget.onSubmit(_pin) : null,
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPress});
  final ValueChanged<String> onPress;

  static const _keys = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫' //
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final k in _keys)
          k.isEmpty
              ? const SizedBox.shrink()
              : Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => onPress(k),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(k,
                            style: AppText.mono(
                                size: 22, weight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
      ],
    );
  }
}
