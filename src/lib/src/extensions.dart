import 'package:flutter/widgets.dart';
import 'core/observable.dart';
import 'locator/fairy_resolver.dart';

/// Extension methods on [BuildContext] for convenient ViewModel access.
extension FairyContextExtensions on BuildContext {
  /// Resolves a ViewModel of type [T] from the context.
  ///
  /// This is a convenience method that calls [Fairy.of].
  ///
  /// Searches in this order:
  /// 1. Nearest [FairyScope] in widget tree
  /// 2. Global [FairyLocator]
  ///
  /// Throws [StateError] if no ViewModel of type [T] is found.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   final viewModel = context.of<CounterViewModel>();
  ///   viewModel.incrementCommand.execute();
  /// }
  /// ```
  ///
  /// See also:
  /// - [maybeOf], which returns `null` instead of throwing when not found
  T of<T extends ObservableObject>() => Fairy.of<T>(this);

  /// Attempts to resolve a ViewModel of type [T], returning `null` if not found.
  ///
  /// Unlike [of], this method does not throw when the ViewModel is not found.
  ///
  /// Example:
  /// ```dart
  /// final vm = context.maybeOf<OptionalViewModel>();
  /// if (vm != null) {
  ///   // Use the ViewModel
  /// }
  /// ```
  T? maybeOf<T extends ObservableObject>() => Fairy.maybeOf<T>(this);
}