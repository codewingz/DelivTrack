/// Digits-only form of a phone number, used for duplicate detection and search.
/// Pakistan numbers written as +92…, 0092… or 92… become 0… (e.g. +92 300 1234567 -> 03001234567).
String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) return '0${digits.substring(4)}';
  if (digits.startsWith('92') && digits.length == 12) {
    return '0${digits.substring(2)}';
  }
  return digits;
}

/// Accepts digits, spaces, dashes and one leading +. After normalizing the number
/// must have 10-15 digits, and Pakistan mobiles (03…) must have exactly 11.
bool isValidPhone(String raw) {
  final trimmed = raw.trim();
  if (!RegExp(r'^\+?[0-9\s-]+$').hasMatch(trimmed)) return false;
  final digits = normalizePhone(trimmed);
  if (digits.length < 10 || digits.length > 15) return false;
  if (digits.startsWith('03') && digits.length != 11) return false;
  return true;
}

/// Digits to look for when a user searches by phone. Like [normalizePhone] but also works for
/// partly typed numbers: "+92 301 22" -> "030122" (so it matches stored 0301… numbers).
String phoneSearchDigits(String raw) {
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+92')) return '0${digits.substring(2)}';
  if (digits.startsWith('0092')) return '0${digits.substring(4)}';
  return digits;
}
