/// Utility functions for equality comparisons.

/// Deep equality check for collections.
///
/// Returns `true` if two lists have the same elements in the same order.
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}

/// Deep equality check for maps.
///
/// Returns `true` if two maps have the same keys and values.
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  if (a.length != b.length) {
    return false;
  }

  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }

  return true;
}

/// Deep equality check for sets.
///
/// Returns `true` if two sets contain the same elements.
bool setEquals<T>(Set<T>? a, Set<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  if (a.length != b.length) {
    return false;
  }

  return a.containsAll(b);
}
