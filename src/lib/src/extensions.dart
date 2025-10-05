import 'package:flutter/widgets.dart';
import 'core/observable.dart';
import 'locator/viewmodel_locator.dart';

/// Extension methods on [BuildContext] for convenient ViewModel access.
extension FairyContextExtensions on BuildContext {
  /// Resolves a ViewModel of type [T] from the context.
  ///
  /// This is a convenience method that calls [ViewModelLocator.resolve].
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
  ///   final viewModel = context.viewModel<CounterViewModel>();
  ///   return Text('Count: ${viewModel.count.value}');
  /// }
  /// ```
  T viewModel<T extends ObservableObject>() => ViewModelLocator.resolve<T>(this);

  /// Attempts to resolve a ViewModel of type [T], returning `null` if not found.
  ///
  /// Unlike [viewModel], this method does not throw when the ViewModel is not found.
  ///
  /// Example:
  /// ```dart
  /// final vm = context.tryViewModel<OptionalViewModel>();
  /// if (vm != null) {
  ///   // Use the ViewModel
  /// }
  /// ```
  T? tryViewModel<T extends ObservableObject>() => ViewModelLocator.tryResolve<T>(this);
}
