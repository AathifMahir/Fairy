import 'package:fairy/src/internal/fairy_scope_bridge.dart';
import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import 'fairy_locator.dart';
import 'fairy_scope.dart';

/// Unified ViewModel resolution logic for the Fairy framework.
///
/// [Fairy] provides a single point of resolution that checks:
/// 1. Nearest [FairyScope] in the widget tree
/// 2. Global [FairyLocator] singleton
///
/// This is used internally by `Bind` and `Command` widgets to automatically
/// resolve ViewModels without requiring manual lookup code.
///
/// Example (typically used internally):
/// ```dart
/// final viewModel = Fairy.of<CounterViewModel>(context);
/// ```
///
/// Resolution order:
/// - First checks the nearest [FairyScope] ancestor
/// - If not found, checks [FairyLocator.instance]
/// - If still not found, throws [StateError]
class Fairy {
  /// Resolves a ViewModel of type [T] from the context.
  ///
  /// Searches in this order:
  /// 1. Nearest [FairyScope] in widget tree
  /// 2. Global [FairyLocator]
  ///
  /// Throws [StateError] if no ViewModel of type [T] is found.
  ///
  /// This is the idiomatic Flutter way to access ViewModels, similar to
  /// `Provider.of<T>(context)` or `Theme.of(context)`.
  ///
  /// Example:
  /// ```dart
  /// // In a widget
  /// final vm = Fairy.of<MyViewModel>(context);
  /// vm.doSomething();
  /// ```
  ///
  Fairy._();

  static T of<T extends ObservableObject>(BuildContext context) {
    // Check if we're in a bridged overlay first
    final bridgedScope = FairyScopeBridge.of(context);
    if (bridgedScope != null && bridgedScope.contains<T>()) {
      return bridgedScope.get<T>();
    }
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
  /// Unlike [of], this method does not throw an exception when the
  /// ViewModel is not found.
  ///
  /// This is useful when you're not sure if a ViewModel is available in the tree.
  ///
  /// Example:
  /// ```dart
  /// final vm = Fairy.maybeOf<MyViewModel>(context);
  /// if (vm != null) {
  ///   vm.doSomething();
  /// }
  /// ```
  static T? maybeOf<T extends ObservableObject>(BuildContext context) {
    // Check if we're in a bridged overlay first
    final bridgedScope = FairyScopeBridge.of(context);
    if (bridgedScope != null && bridgedScope.contains<T>()) {
      return bridgedScope.get<T>();
    }
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

  /// Bridges parent BuildContext to overlay widget tree.
  ///
  /// **Problem:** Overlays (dialogs, bottom sheets, menus) create separate
  /// widget trees that can't access parent FairyScopes via normal context lookup.
  ///
  /// **Solution:** `Fairy.bridge()` captures the parent context's FairyScope
  /// and makes it available to the overlay's context.
  ///
  /// **Example:**
  /// ```dart
  /// void _showDialog(BuildContext context) {
  ///   showDialog(
  ///     context: context,
  ///     builder: (_) => Fairy.bridge(
  ///       context: context, // Parent context with FairyScope
  ///       child: AlertDialog(
  ///         // Command and Bind widgets now work!
  ///         actions: [
  ///           Command<MyViewModel>(
  ///             command: (vm) => vm.saveCommand,
  ///             builder: (ctx, execute, canExecute, isRunning) =>
  ///               TextButton(onPressed: execute, child: Text('Save')),
  ///           ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  ///
  /// **What it does:**
  /// - Looks up parent context's FairyScope
  /// - Creates an InheritedWidget that bridges the same scope to overlay
  /// - `Fairy.of<T>()` inside overlay now works seamlessly
  ///
  /// **When to use:**
  /// - Dialogs (`showDialog`)
  /// - Bottom sheets (`showModalBottomSheet`)
  /// - Menus (`showMenu`)
  /// - Any overlay that creates a new route
  static Widget bridge({
    required BuildContext context,
    required Widget child,
  }) {
    // Look up parent's FairyScope
    final parentScope = FairyScope.of(context);

    if (parentScope == null) {
      // No FairyScope in parent, just return child
      // (Fairy.of will fall back to FairyLocator if needed)
      return child;
    }

    // Bridge the parent scope to overlay
    return FairyScopeBridge(
      scopeData: parentScope,
      child: child,
    );
  }
}


