import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

/// A large centered KMF amount entry — the focal control of the cash and card
/// flows. Reports the integer minor-unit value (KMF has no decimals here).
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    required this.onChanged,
    this.autofocus = true,
    this.quickAmounts = const [1000, 5000, 10000, 25000],
  });

  final ValueChanged<int> onChanged;
  final bool autofocus;
  final List<int> quickAmounts;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(int value) {
    _controller.text = value.toString();
    widget.onChanged(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            IntrinsicWidth(
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (v) {
                  widget.onChanged(int.tryParse(v) ?? 0);
                  setState(() {});
                },
                style: AppText.mono(size: 44, weight: FontWeight.w600),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: AppText.mono(
                      size: 44,
                      weight: FontWeight.w600,
                      color: AppColors.inkFaint),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('KMF',
                  style: AppText.mono(size: 16, color: AppColors.inkLow)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final a in widget.quickAmounts)
              _Chip(label: '+${fmtKmfNoUnit(a)}', onTap: () {
                final current = int.tryParse(_controller.text) ?? 0;
                _set(current + a);
              }),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderHi),
          ),
          child: Text(label,
              style: AppText.mono(size: 13, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
