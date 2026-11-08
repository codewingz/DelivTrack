/// Names of the entries whose value differs between [before] and [after]
/// (added, removed or changed). Compares nested maps and lists by value.
List<String> changedKeys(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final keys = {...before.keys, ...after.keys}.toList()..sort();
  return [
    for (final key in keys)
      if (!_deepEqual(before[key], after[key])) key,
  ];
}

bool _deepEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _deepEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) _deepEqual(a[i], b[i])]
            .every((same) => same);
  }
  return a == b;
}
