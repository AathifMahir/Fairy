import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:fairy/src/locator/fairy_locator.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:flutter/foundation.dart';

/// Internal implementation of [FairyScopeLocator].
///
/// This class is sealed to prevent external instantiation and ensure
/// locator instances are only created during FairyScope initialization.
///
/// **Performance Optimization:** Uses hybrid flattening approach:
/// 1. Current scope checked directly (O(1), supports future lazy loading)
/// 2. Parent scopes flattened into single map (O(1) lookup instead of O(n) iteration)
/// 3. Pre-collected during construction to avoid repeated tree traversal
///
/// **Memory Safety:** Uses weak references in flattened map to prevent
/// retention of disposed parent scopes in edge cases.
@internal
class FairyScopeLocatorImpl implements FairyScopeLocator {
  final FairyScopeData _currentScopeData;
  final Map<Type, WeakReference<ObservableObject>> _flattenedParents;
  bool _isValid = true;

  FairyScopeLocatorImpl(
    this._currentScopeData,
    List<FairyScopeData> parentScopes,
  ) : _flattenedParents = _flattenParentScopes(parentScopes);

  /// Flattens parent scope registries into a single map for O(1) lookup.
  ///
  /// Parent scopes are processed from farthest to nearest, so nearest parents
  /// override farthest in case of type conflicts (which shouldn't happen in
  /// well-designed hierarchies, but this ensures correct behavior).
  ///
  /// Uses weak references to prevent memory leaks if parent scopes are disposed.
  static Map<Type, WeakReference<ObservableObject>> _flattenParentScopes(
    List<FairyScopeData> parentScopes,
  ) {
    final flattened = <Type, WeakReference<ObservableObject>>{};
    
    // Iterate from farthest to nearest (reversed order)
    // This ensures nearest parent wins in case of duplicate types
    for (final parentData in parentScopes.reversed) {
      for (final entry in parentData.registry.entries) {
        flattened[entry.key] = WeakReference<ObservableObject>(entry.value);
      }
    }
    
    return flattened;
  }

  /// Invalidates this locator after initialization is complete.
  void invalidate() {
    _isValid = false;
  }

  @override
  T get<T extends Object>() {
    assert(_isValid, 'FairyScopeLocator used after invalidation');

    if (!_isValid) {
      throw StateError(
        'FairyScopeLocator can only be used during ViewModel initialization.\n'
        'Do not store references to the locator or use it outside the factory function.\n'
        '\n'
        'Valid usage:\n'
        '  FairyScope(\n'
        '    viewModel: (locator) => MyViewModel(\n'
        '      service: locator.get<MyService>(), // ✓ OK\n'
        '    ),\n'
        '  )\n'
        '\n'
        'Invalid usage:\n'
        '  class MyViewModel {\n'
        '    late final FairyScopeLocator _locator;\n'
        '    MyViewModel(FairyScopeLocator locator) {\n'
        '      _locator = locator; // ✗ DON\'T store it\n'
        '    }\n'
        '    void someMethod() {\n'
        '      _locator.get<Service>(); // ✗ Will throw\n'
        '    }\n'
        '  }',
      );
    }

    // HYBRID APPROACH for optimal performance:
    
    // 1. Always check current scope directly (O(1))
    //    This supports future lazy creation and sequential dependencies
    final currentResult = _currentScopeData.registry[T];
    if (currentResult != null) {
      return currentResult as T;
    }

    // 2. Check flattened parent scopes (O(1) instead of O(n) iteration)
    //    Uses weak references to prevent memory leaks
    final parentWeakRef = _flattenedParents[T];
    if (parentWeakRef != null) {
      final parentResult = parentWeakRef.target;
      if (parentResult != null) {
        return parentResult as T;
      }
      // Weak reference was garbage collected - fall through to next step
    }

    // 3. Fall back to global FairyLocator
    try {
      return FairyLocator.instance.get<T>();
    } catch (e) {
      throw StateError(
        'No dependency of type $T found in FairyScope hierarchy or FairyLocator.\n'
        'Make sure to:\n'
        '1. Register services with FairyLocator.instance.registerSingleton<$T>(...)\n'
        '2. Or provide ViewModels via parent FairyScope widgets',
      );
    }
  }
}