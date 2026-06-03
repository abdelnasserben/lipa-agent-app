import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/phone_input_formatter.dart';

/// Bold small label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return Text(text, style: AppText.ui(size: 13, weight: FontWeight.w600));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: AppText.ui(size: 13, weight: FontWeight.w600)),
        trailing!,
      ],
    );
  }
}

/// Generic boxed single-line text field used across forms.
class BoxedTextField extends StatelessWidget {
  const BoxedTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.mono = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool mono;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          style: mono
              ? AppText.mono(size: 16)
              : AppText.ui(size: 15, weight: FontWeight.w500),
          decoration: InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isDense: true,
            hintText: hintText,
          ),
        ),
      ),
    );
  }
}

/// Comorian phone input with a fixed +269 prefix chip.
class PhoneInput extends StatelessWidget {
  const PhoneInput({super.key, required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Text('+269',
                style: AppText.mono(size: 15, weight: FontWeight.w600)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                inputFormatters: const [ComorianPhoneFormatter()],
                onChanged: onChanged,
                style: AppText.mono(size: 16, letterSpacing: 0.6),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '300 00 00',
                  hintStyle: AppText.mono(
                      size: 16,
                      letterSpacing: 0.6,
                      color: AppColors.inkFaint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Obscured PIN digits input (4–8) with an 0/8 counter.
class PinDigitsInput extends StatelessWidget {
  const PinDigitsInput({super.key, required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: AppText.mono(size: 22, letterSpacing: 6),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                hintText: '••••',
              ),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Text('${controller.text.length}/8',
                style: AppText.mono(size: 12.5, color: AppColors.inkLow)),
          ),
        ],
      ),
    );
  }
}
