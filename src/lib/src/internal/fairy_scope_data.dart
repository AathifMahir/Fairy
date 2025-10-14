import 'package:fairy/src/core/observable.dart';
import 'package:flutter/foundation.dart';

/// Data holder for managing scoped ViewModels within a [FairyScope].
///
/// This class maintains a local registry of ViewModels and tracks which ones
/// were created by the scope (and therefore should be disposed by it).
///
/// **Internal API:** This class is intended for internal use by FairyScope only.
/// Do not use it directly in application code.
@internal
class FairyScopeData {
  final Map<Type, ObservableObject> registry = {};
  final Set<Type> _ownedTypes = {};

  /// Registers a ViewModel instance of type [T].
  ///
  /// [owned] indicates whether this scope created the instance and is
  /// responsible for disposing it.
  void register<T extends ObservableObject>(T instance, {bool owned = false}) {
    registry[T] = instance;
    if (owned) {
      _ownedTypes.add(T);
    }
  }

  /// Registers a ViewModel instance using its runtime type.
  ///
  /// This is useful when iterating over a list of ViewModels where the
  /// compile-time type is not available.
  void registerDynamic(ObservableObject instance, {bool owned = false}) {
    final type = instance.runtimeType;
    registry[type] = instance;
    if (owned) {
      _ownedTypes.add(type);
    }
  }

  /// Retrieves a ViewModel of type [T].
  ///
  /// Throws [StateError] if no ViewModel of type [T] is registered.
  T get<T extends ObservableObject>() {
    if (!registry.containsKey(T)) {
      throw StateError('No ViewModel of type $T found in FairyScope');
    }
    return registry[T] as T;
  }

  /// Checks if a ViewModel of type [T] is registered.
  bool contains<T extends ObservableObject>() => registry.containsKey(T);

  /// Disposes all ViewModels that this scope owns.
  ///
  /// Only disposes ViewModels that were created by this scope (marked as owned).
  void dispose() {
    for (final type in _ownedTypes) {
      final vm = registry[type];
      if (vm != null) {
        vm.dispose();
      }
    }
    _ownedTypes.clear();
    registry.clear();
  }
}