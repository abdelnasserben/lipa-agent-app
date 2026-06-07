/// Frontend input validation, shared across the agent app.
///
/// Goals (in order):
///  1. Block malformed input from ever leaving the device — no wasted API calls
///     on payloads the backend will reject anyway (spec §6).
///  2. Apply the few business rules we can check client-side ahead of the server
///     (Comorian operator prefixes, "new PIN must differ from current", …).
///
/// The server stays authoritative; these checks only fail fast on the obvious.
library;

/// Comorian mobile numbers are 7 digits and, with the two operators live in the
/// country today, start with `3` (Telma/Telco) or `4` (Comores Câbles / others).
/// Backend still validates 4..15 digits (spec §6.1), so this is a stricter
/// frontend gate, not a contract change.
class PhoneValidator {
  /// Number of significant digits in a local Comorian mobile number.
  static const int length = 7;

  /// Allowed leading digits = the live operators in the archipelago.
  static const Set<String> validPrefixes = {'3', '4'};

  /// Strips spaces/punctuation, returning only the digits the API expects.
  static String digitsOf(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// True when [raw] is a complete, well-formed local number ready to send.
  static bool isComplete(String raw) {
    final d = digitsOf(raw);
    return d.length == length && validPrefixes.contains(d[0]);
  }

  /// A French error message for an incomplete/invalid number, or null when ok.
  /// Returns null for an empty field so the form doesn't shout before the user
  /// has typed anything.
  static String? errorText(String raw) {
    final d = digitsOf(raw);
    if (d.isEmpty) return null;
    if (!validPrefixes.contains(d[0])) {
      return 'Le numéro doit commencer par 3 ou 4.';
    }
    if (d.length < length) return 'Le numéro doit contenir 7 chiffres.';
    return null;
  }
}

/// Auth PIN rules (spec §3.6 / §6.1): 4 to 8 digits.
class PinValidator {
  static const int minLength = 4;
  static const int maxLength = 8;

  static String digitsOf(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// True when [raw] is a syntactically valid PIN (length only).
  static bool isValid(String raw) {
    final d = digitsOf(raw);
    return d.length >= minLength && d.length <= maxLength;
  }
}
