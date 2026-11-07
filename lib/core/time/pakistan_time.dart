// Business dates use Pakistan time. Pakistan has had no daylight saving since 2009, so it is a
// fixed UTC+5 offset; no time-zone database is needed.
const _pakistanOffset = Duration(hours: 5);

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Source of "now" so date logic can be tested.
class Clock {
  const Clock();
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// The Pakistan calendar date of [instant] as "yyyy-MM-dd".
String pakistanDate(DateTime instant) {
  final local = instant.toUtc().add(_pakistanOffset);
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

/// "2026-11-07" -> "7 Nov 2026". Returns the input unchanged when it is not a valid date string.
String formatDate(String yyyyMmDd) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(yyyyMmDd);
  if (match == null) return yyyyMmDd;
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return yyyyMmDd;
  return '$day ${_monthNames[month - 1]} ${match[1]}';
}
