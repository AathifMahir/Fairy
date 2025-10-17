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
  final List<Type> _ownedTypes = []; // Changed from Set to List to maintain order

  /// Registers a ViewModel instance of type [T].
  ///
  /// [owned] indicates whether this scope created the instance and is
  /// responsible for disposing it.
  ///
  /// Throws [StateError] if a ViewModel of type [T] is already registered.
  void register<T extends ObservableObject>(T instance, {bool owned = false}) {
    if (registry.containsKey(T)) {
      throw StateError(
        'ViewModel of type $T is already registered in this FairyScope.\n'
        'Each scope can only contain one instance of each ViewModel type.\n'
        'If you need multiple instances, use different ViewModel classes.',
      );
    }
    registry[T] = instance;
    if (owned) {
      _ownedTypes.add(T);
    }
  }

  /// Registers a ViewModel instance using its runtime type.
  ///
  /// This is useful when iterating over a list of ViewModels where the
  /// compile-time type is not available.
  ///
  /// Throws [StateError] if a ViewModel of this type is already registered.
  void registerDynamic(ObservableObject instance, {bool owned = false}) {
    final type = instance.runtimeType;
    if (registry.containsKey(type)) {
      throw StateError(
        'ViewModel of type $type is already registered in this FairyScope.\n'
        'Each scope can only contain one instance of each ViewModel type.\n'
        'If you need multiple instances, use different ViewModel classes.',
      );
    }
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
    final instance = registry[T];
    if (instance == null) {
      throw StateError('Type $T is not registered in this scope');
    }
    
    if (instance.isDisposed) {
      throw StateError(
        'ViewModel of type $T has been disposed and cannot be accessed.\n'
        'This usually happens when:\n'
        '1. FairyScope was removed from the widget tree\n'
        '2. ViewModel was manually disposed\n'
        '3. Widget is trying to access VM during disposal phase',
      );
    }
    return instance as T;
  }

  /// Checks if a ViewModel of type [T] is registered.
  bool contains<T extends ObservableObject>() => registry.containsKey(T);

  /// Disposes all ViewModels that this scope owns.
  ///
  /// Only disposes ViewModels that were created by this scope (marked as owned).
  /// ViewModels are disposed in reverse registration order (LIFO - last in, first out).
  void dispose() {
    // Dispose in reverse order
    for (final type in _ownedTypes.reversed) {
      final vm = registry[type];
      if (vm != null && !vm.isDisposed) {
        vm.dispose();
      }
    }
    _ownedTypes.clear();
    registry.clear();
  }
}