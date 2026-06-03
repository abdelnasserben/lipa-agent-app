import 'package:intl/intl.dart';

/// Formatting helpers, shared with the Lipa Customer design system.
/// All amounts are KMF integer minor-units.

final NumberFormat _grouped = NumberFormat.decimalPattern('fr_FR');

/// "184 250" — grouped, no unit, absolute value.
String fmtKmfNoUnit(int n) => _grouped.format(n.abs());

/// "−184 250 KMF" / "+184 250 KMF". Uses a minus sign (U+2212).
String fmtKmf(int n, {bool signed = false}) {
  final grouped = fmtKmfNoUnit(n);
  final sign = n < 0
      ? '−'
      : signed
          ? '+'
          : '';
  return '$sign$grouped KMF';
}

/// "+269 300 00 00" — groups a Comorian local number as 3-2-2.
/// The API always receives the raw digits (no spaces); this is display only.
String fmtPhone(String countryCode, String number) =>
    '+$countryCode ${fmtPhoneLocal(number)}';

/// Groups a local Comorian number as "XXX XX XX" (e.g. "300 00 00").
/// Falls back to grouping the leading 3 digits then pairs, so partial input
/// while typing ("300", "300 0", "300 00") still reads naturally.
String fmtPhoneLocal(String number) {
  final d = number.replaceAll(RegExp(r'\D'), '');
  if (d.length <= 3) return d;
  final head = d.substring(0, 3);
  final rest = d.substring(3);
  final pairs = <String>[];
  for (var i = 0; i < rest.length; i += 2) {
    pairs.add(rest.substring(i, (i + 2).clamp(0, rest.length)));
  }
  return '$head ${pairs.join(' ')}'.trim();
}

/// "cus_…5a90" — short id with an ellipsis.
String shortId(String s) {
  if (s.length <= 9) return s;
  return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
}

/// French relative time, e.g. "à l'instant", "il y a 5 min", "il y a 3 h".
String fmtRelativeFr(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final sec = ref.difference(when).inSeconds;
  if (sec < 60) return 'à l’instant';
  final min = sec ~/ 60;
  if (min < 60) return 'il y a $min min';
  final h = min ~/ 60;
  if (h < 24) return 'il y a $h h';
  final days = h ~/ 24;
  if (days < 7) return 'il y a $days j';
  return DateFormat('dd MMM', 'fr_FR').format(when);
}

/// "14 mai 2026, 11h48"
String fmtDateTimeFr(DateTime dt) =>
    DateFormat("dd MMM yyyy, HH'h'mm", 'fr_FR').format(dt);

/// "14 mai 2026"
String fmtDateFr(DateTime dt) => DateFormat('dd MMM yyyy', 'fr_FR').format(dt);

/// "11:48"
String fmtTimeFr(DateTime dt) => DateFormat('HH:mm', 'fr_FR').format(dt);

/// Parses an ISO-8601 instant defensively; returns null on garbage rather than
/// throwing, so a single malformed timestamp never crashes a list.
DateTime? tryParseInstant(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
