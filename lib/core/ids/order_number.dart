/// Prefix of internal order numbers.
const orderPrefix = 'ADT';

/// 1 -> "ADT-000001"; numbers past 999999 simply grow ("ADT-1000000").
String formatOrderNumber(int sequence) {
  assert(sequence >= 1, 'order sequences start at 1');
  return '$orderPrefix-${sequence.toString().padLeft(6, '0')}';
}
