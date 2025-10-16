
/// Utility class providing deep equality checks for collections.
///
/// Supports recursive deep equality for nested collections including
/// [List], [Map], [Set], and [Iterable].
///
/// **Example:**
/// ```dart
/// // Nested collections
/// final list1 = [[1, 2], [3, 4]];
/// final list2 = [[1, 2], [3, 4]];
/// Equals.deepCollectionEquals(list1, list2); // true
///
/// // Custom types with collections
/// class User {
///   final String name;
///   final List<String> tags;
///
///   @override
///   bool operator ==(Object other) =>
///       identical(this, other) ||
///       other is User &&
///           name == other.name &&
///           Equals.listEquals(tags, other.tags);
///
///   @override
///   int get hashCode => name.hashCode ^ Equals.listHash(tags);
/// }
/// ```
class Equals {
  Equals._();

  /// Deep equality check for any collection type.
  ///
  /// Recursively compares nested collections (List, Map, Set, Iterable).
  /// For non-collection objects, uses their `==` operator.
  ///
  /// **Example:**
  /// ```dart
  /// // Deeply nested lists
  /// final nested1 = [[1, 2], [3, 4]];
  /// final nested2 = [[1, 2], [3, 4]];
  /// Equals.deepCollectionEquals(nested1, nested2); // true
  ///
  /// // Mixed nested structures
  /// final mixed1 = {'users': [{'name': 'Alice'}, {'name': 'Bob'}]};
  /// final mixed2 = {'users': [{'name': 'Alice'}, {'name': 'Bob'}]};
  /// Equals.deepCollectionEquals(mixed1, mixed2); // true
  /// ```
  static bool deepCollectionEquals(Object? e1, Object? e2) {
    // Identical check (fast path)
    if (identical(e1, e2)) return true;
    if (e1 == null || e2 == null) return false;

    // Set equality
    if (e1 is Set) {
      if (e2 is! Set) return false;
      return _setEquals(e1, e2, deepCollectionEquals);
    }

    // Map equality
    if (e1 is Map) {
      if (e2 is! Map) return false;
      return _mapEquals(e1, e2, deepCollectionEquals);
    }

    // List equality (order matters)
    if (e1 is List) {
      if (e2 is! List) return false;
      return _listEquals(e1, e2, deepCollectionEquals);
    }

    // Iterable equality (order matters)
    if (e1 is Iterable) {
      if (e2 is! Iterable) return false;
      return _iterableEquals(e1, e2, deepCollectionEquals);
    }

    // Fall back to == operator for non-collections
    return e1 == e2;
  }

  /// Deep hash code for any collection type.
  ///
  /// Recursively computes hash for nested collections.
  ///
  /// **Example:**
  /// ```dart
  /// class User {
  ///   final String name;
  ///   final List<String> tags;
  ///
  ///   @override
  ///   int get hashCode => name.hashCode ^ Equals.deepCollectionHash(tags);
  /// }
  /// ```
  static int deepCollectionHash(Object? o) {
    if (o == null) return 0;
    if (o is Set) return _setHash(o, deepCollectionHash);
    if (o is Map) return _mapHash(o, deepCollectionHash);
    if (o is List) return _listHash(o, deepCollectionHash);
    if (o is Iterable) return _iterableHash(o, deepCollectionHash);
    return o.hashCode;
  }

  /// Deep equality check for lists.
  ///
  /// Returns `true` if two lists have the same elements in the same order.
  /// Uses element-by-element comparison with deep equality for nested collections.
  ///
  /// **Example:**
  /// ```dart
  /// final list1 = [[1, 2], [3, 4]];
  /// final list2 = [[1, 2], [3, 4]];
  /// Equals.listEquals(list1, list2); // true (nested lists)
  /// ```
  static bool listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return _listEquals(a, b, deepCollectionEquals);
  }

  /// Hash code for lists using deep equality.
  ///
  /// **Example:**
  /// ```dart
  /// final list = [[1, 2], [3, 4]];
  /// final hash = Equals.listHash(list);
  /// ```
  static int listHash<T>(List<T>? list) {
    if (list == null) return 0;
    return _listHash(list, deepCollectionHash);
  }

  /// Deep equality check for maps.
  ///
  /// Returns `true` if two maps have the same keys and values.
  /// Uses deep equality for both keys and values.
  ///
  /// **Example:**
  /// ```dart
  /// final map1 = {'a': [1, 2], 'b': [3, 4]};
  /// final map2 = {'a': [1, 2], 'b': [3, 4]};
  /// Equals.mapEquals(map1, map2); // true (nested lists in values)
  /// ```
  static bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return _mapEquals(a, b, deepCollectionEquals);
  }

  /// Hash code for maps using deep equality.
  ///
  /// **Example:**
  /// ```dart
  /// final map = {'a': [1, 2], 'b': [3, 4]};
  /// final hash = Equals.mapHash(map);
  /// ```
  static int mapHash<K, V>(Map<K, V>? map) {
    if (map == null) return 0;
    return _mapHash(map, deepCollectionHash);
  }

  /// Deep equality check for sets.
  ///
  /// Returns `true` if two sets have the same elements (order doesn't matter).
  /// Uses deep equality for element comparison.
  ///
  /// **Example:**
  /// ```dart
  /// final set1 = {[1, 2], [3, 4]};
  /// final set2 = {[3, 4], [1, 2]}; // Different order
  /// Equals.setEquals(set1, set2); // true (order doesn't matter)
  /// ```
  static bool setEquals<T>(Set<T>? a, Set<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return _setEquals(a, b, deepCollectionEquals);
  }

  /// Hash code for sets using deep equality.
  ///
  /// **Example:**
  /// ```dart
  /// final set = {[1, 2], [3, 4]};
  /// final hash = Equals.setHash(set);
  /// ```
  static int setHash<T>(Set<T>? set) {
    if (set == null) return 0;
    return _setHash(set, deepCollectionHash);
  }

  /// Creates a deep equality function for type T.
  ///
  /// Returns a function that performs deep collection equality for collection types,
  /// or `null` for non-collection types (which will use default `==` operator).
  ///
  /// This is used internally by [ObservableProperty] when `deepEquality: true`.
  ///
  /// **Example:**
  /// ```dart
  /// final equals = Equals.deepEquals<List<int>>();
  /// final same = equals([1, 2, 3], [1, 2, 3]); // true
  /// ```
  static bool Function(T?, T?)? deepEquals<T>() {
    final typeString = T.toString();

    // Check if T is a collection type
    if (typeString.startsWith('List<') ||
        typeString.startsWith('Map<') ||
        typeString.startsWith('Set<') ||
        T == List ||
        T == Map ||
        T == Set) {
      return (a, b) => deepCollectionEquals(a, b);
    }

    return null; // Use default == operator
  }

  // ========================================================================
  // Internal implementation methods
  // ========================================================================

  static bool _listEquals<T>(
    List<T> a,
    List<T> b,
    bool Function(Object?, Object?) elementEquals,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!elementEquals(a[i], b[i])) return false;
    }
    return true;
  }

  static int _listHash<T>(
    List<T> list,
    int Function(Object?) elementHash,
  ) {
    var hash = 0;
    for (var i = 0; i < list.length; i++) {
      var c = elementHash(list[i]);
      hash = (hash + c) & 0x3fffffff;
      hash = (hash + (hash << 10)) & 0x3fffffff;
      hash ^= (hash >> 6);
    }
    hash = (hash + (hash << 3)) & 0x3fffffff;
    hash ^= (hash >> 11);
    hash = (hash + (hash << 15)) & 0x3fffffff;
    return hash;
  }

  static bool _mapEquals<K, V>(
    Map<K, V> a,
    Map<K, V> b,
    bool Function(Object?, Object?) elementEquals,
  ) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!elementEquals(a[key], b[key])) return false;
    }
    return true;
  }

  static int _mapHash<K, V>(
    Map<K, V> map,
    int Function(Object?) elementHash,
  ) {
    var hash = 0;
    for (var entry in map.entries) {
      var keyHash = elementHash(entry.key);
      var valueHash = elementHash(entry.value);
      hash = (hash + keyHash) & 0x3fffffff;
      hash = (hash + valueHash) & 0x3fffffff;
    }
    hash = (hash + (hash << 3)) & 0x3fffffff;
    hash ^= (hash >> 11);
    hash = (hash + (hash << 15)) & 0x3fffffff;
    return hash;
  }

  static bool _setEquals<T>(
    Set<T> a,
    Set<T> b,
    bool Function(Object?, Object?) elementEquals,
  ) {
    if (a.length != b.length) return false;

    // For sets with deep equality, we need to check if each element in 'a'
    // has a corresponding element in 'b' using deep equality
    for (var element in a) {
      var found = false;
      for (var other in b) {
        if (elementEquals(element, other)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  static int _setHash<T>(
    Set<T> set,
    int Function(Object?) elementHash,
  ) {
    // For sets, order doesn't matter, so we use XOR which is commutative
    var hash = 0;
    for (var element in set) {
      var c = elementHash(element);
      hash ^= c;
    }
    return hash;
  }

  static bool _iterableEquals<T>(
    Iterable<T> a,
    Iterable<T> b,
    bool Function(Object?, Object?) elementEquals,
  ) {
    var it1 = a.iterator;
    var it2 = b.iterator;
    while (true) {
      var hasNext1 = it1.moveNext();
      var hasNext2 = it2.moveNext();
      if (hasNext1 != hasNext2) return false;
      if (!hasNext1) return true;
      if (!elementEquals(it1.current, it2.current)) return false;
    }
  }

  static int _iterableHash<T>(
    Iterable<T> iterable,
    int Function(Object?) elementHash,
  ) {
    var hash = 0;
    for (var element in iterable) {
      var c = elementHash(element);
      hash = (hash + c) & 0x3fffffff;
      hash = (hash + (hash << 10)) & 0x3fffffff;
      hash ^= (hash >> 6);
    }
    hash = (hash + (hash << 3)) & 0x3fffffff;
    hash ^= (hash >> 11);
    hash = (hash + (hash << 15)) & 0x3fffffff;
    return hash;
  }
}
