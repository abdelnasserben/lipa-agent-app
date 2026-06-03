import 'package:flutter/services.dart';

import 'formatters.dart';

/// Live-formats a Comorian local number as "XXX XX XX" while the user types
/// (e.g. "300 00 00"). Only digits are kept; spaces are presentation only, so
/// `controller.text.replaceAll(RegExp(r'\D'), '')` always yields the raw
/// digits the API expects. Capped at 7 digits (3 + 2 + 2).
class ComorianPhoneFormatter extends TextInputFormatter {
  const ComorianPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 7 ? digits.substring(0, 7) : digits;
    final formatted = fmtPhoneLocal(capped);
    // Keep the caret at the end — this field is only ever appended/backspaced.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
