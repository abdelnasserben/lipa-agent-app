import 'package:flutter/services.dart';

import 'formatters.dart';
import 'validators.dart';

/// Live-formats a Comorian local number as "XXX XX XX" while the user types
/// (e.g. "300 00 00"). Only digits are kept; spaces are presentation only, so
/// `controller.text.replaceAll(RegExp(r'\D'), '')` always yields the raw
/// digits the API expects. Capped at 7 digits (3 + 2 + 2), and the first digit
/// is constrained to a live operator prefix (3 or 4) so an invalid number can
/// never even be typed — the backend would only reject it anyway.
class ComorianPhoneFormatter extends TextInputFormatter {
  const ComorianPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Refuse a leading digit that isn't a known operator prefix: drop it rather
    // than letting the user build a number the API will never accept.
    if (digits.isNotEmpty && !PhoneValidator.validPrefixes.contains(digits[0])) {
      return oldValue;
    }
    final capped =
        digits.length > PhoneValidator.length
            ? digits.substring(0, PhoneValidator.length)
            : digits;
    final formatted = fmtPhoneLocal(capped);
    // Keep the caret at the end — this field is only ever appended/backspaced.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
