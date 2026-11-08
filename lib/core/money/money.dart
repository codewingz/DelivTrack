// Money is stored as whole paisa (int) and weights as whole grams (int). No floating point.

/// Largest amount accepted anywhere: Rs. 99,999,999.
const maxMoneyPaisa = 99999999 * 100;

/// Largest weight accepted: 9,999.999 kg.
const maxWeightGrams = 9999999;

final _rupeesPattern = RegExp(r'^(\d{1,3}(,\d{3})+|\d+)?(\.\d{0,2})?$');
final _kgPattern = RegExp(r'^\d*(\.\d{0,3})?$');

/// "2,500.5" -> 250050. Returns null when empty, malformed (3+ decimals, letters, bad commas,
/// negative) or above [maxMoneyPaisa].
int? parseRupeesToPaisa(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed == '.' || !_rupeesPattern.hasMatch(trimmed)) {
    return null;
  }
  final parts = trimmed.replaceAll(',', '').split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final paisa = whole * 100 + int.parse(fraction);
  return paisa > maxMoneyPaisa ? null : paisa;
}

/// 250000 -> "Rs. 2,500"; 250050 -> "Rs. 2,500.50"; -50000 -> "-Rs. 500".
String formatRupees(int paisa) {
  final sign = paisa < 0 ? '-' : '';
  final absolute = paisa.abs();
  final whole = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final fraction = absolute % 100;
  return '${sign}Rs. $whole${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
}

/// "1.25" -> 1250 grams. Returns null when empty, malformed (4+ decimals, letters, negative)
/// or above [maxWeightGrams].
int? parseKgToGrams(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed == '.' || !_kgPattern.hasMatch(trimmed)) {
    return null;
  }
  final parts = trimmed.split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final fraction = parts.length > 1 ? parts[1].padRight(3, '0') : '000';
  final grams = whole * 1000 + int.parse(fraction);
  return grams > maxWeightGrams ? null : grams;
}

/// 1250 -> "1.25 kg"; 2000 -> "2 kg"; 5 -> "0.005 kg".
String formatKg(int grams) => formatMeasure(grams, 'kg');

/// [thousandths] of a unit as text: formatMeasure(1250, 'litres') -> "1.25 litres".
String formatMeasure(int thousandths, String unit) {
  final whole = thousandths ~/ 1000;
  final fraction = thousandths % 1000;
  if (fraction == 0) return '$whole $unit';
  return '$whole.${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')} $unit';
}

/// Price of [quantity] pieces at [unitPricePaisa] each.
int pieceLineTotalPaisa({required int quantity, required int unitPricePaisa}) =>
    quantity * unitPricePaisa;

/// Price of [grams] at [pricePerKgPaisa] per kg, rounded half up to a whole paisa.
int weightLineTotalPaisa({required int grams, required int pricePerKgPaisa}) =>
    (grams * pricePerKgPaisa + 500) ~/ 1000;

/// Paisa as text for an input field: 250000 -> "2500", 250050 -> "2500.50" (no "Rs.", no commas).
String plainRupees(int paisa) {
  final whole = paisa ~/ 100;
  final fraction = paisa % 100;
  return fraction == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}

/// Grams as text for an input field: 1250 -> "1.25", 2000 -> "2", 5 -> "0.005".
String plainKg(int grams) {
  final whole = grams ~/ 1000;
  final fraction = grams % 1000;
  if (fraction == 0) return '$whole';
  return '$whole.${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
}
