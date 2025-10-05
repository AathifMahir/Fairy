import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import 'fairy_locator.dart';
import 'fairy_scope.dart';

/// Unified ViewModel resolution logic for the Fairy framework.
///
/// [ViewModelLocator] provides a single point of resolution that checks:
/// 1. Nearest [FairyScope] in the widget tree
/// 2. Global [FairyLocator] singleton
///
/// This is used internally by `Bind` and `Command` widgets to automatically
/// resolve ViewModels without requiring manual lookup code.
///
/// Example (typically used internally):
/// ```dart
/// final viewModel = ViewModelLocator.resolve<CounterViewModel>(context);
/// ```
///
/// Resolution order:
/// - First checks the nearest [FairyScope] ancestor
/// - If not found, checks [FairyLocator.instance]
/// - If still not found, throws [StateError]
class ViewModelLocator {
  /// Resolves a ViewModel of type [T] from the context.
  ///
  /// Searches in this order:
  /// 1. Nearest [FairyScope] in widget tree
  /// 2. Global [FairyLocator]
  ///
  /// Throws [StateError] if no ViewModel of type [T] is found.
  ///
  /// Example:
  /// ```dart
  /// // In a widget
  /// final vm = ViewModelLocator.resolve<MyViewModel>(context);
  /// vm.doSomething();
  /// ```
  static T resolve<T extends ObservableObject>(BuildContext context) {
    // Check nearest FairyScope first
    final scopeData = FairyScope.of(context);
    if (scopeData != null && scopeData.contains<T>()) {
      return scopeData.get<T>();
    }

    // Check global FairyLocator
    if (FairyLocator.instance.contains<T>()) {
      return FairyLocator.instance.get<T>();
    }

    // Not found anywhere
    throw StateError(
      'No ViewModel of type $T found.\n'
      'Make sure to either:\n'
      '  1. Register it in FairyLocator: FairyLocator.instance.registerSingleton<$T>(...)\n'
      '  2. Provide it via FairyScope: FairyScope(create: () => $T(), ...)\n'
      '  3. Wrap your widget tree with a FairyScope containing the ViewModel',
    );
  }

  /// Attempts to resolve a ViewModel of type [T], returning `null` if not found.
  ///
  /// Unlike [resolve], this method does not throw an exception when the
  /// ViewModel is not found.
  ///
  /// Example:
  /// ```dart
  /// final vm = ViewModelLocator.tryResolve<MyViewModel>(context);
  /// if (vm != null) {
  ///   vm.doSomething();
  /// }
  /// ```
  static T? tryResolve<T extends ObservableObject>(BuildContext context) {
    // Check FairyScope
    final scopeData = FairyScope.of(context);
    if (scopeData != null && scopeData.contains<T>()) {
      return scopeData.get<T>();
    }

    // Check FairyLocator
    if (FairyLocator.instance.contains<T>()) {
      return FairyLocator.instance.get<T>();
    }

    return null;
  }
}
