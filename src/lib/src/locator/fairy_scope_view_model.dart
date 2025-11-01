import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';

/// Configuration for ViewModel creation in [FairyScope].
///
/// Defines how to create a ViewModel and when to create it (lazy/eager).
/// ViewModels are always auto-disposed when the scope is removed.
class FairyScopeViewModel<T extends ObservableObject> {
  final T Function(FairyScopeLocator locator) create;
  final bool lazy;
  final Type viewModelType;

  /// Creates a ViewModel configuration.
  ///
  /// [create] is the factory function to create the ViewModel.
  /// It receives a [FairyScopeLocator] for dependency resolution.
  ///
  /// [lazy] determines when the ViewModel is created:
  /// - `true` (default): Created on first access
  /// - `false`: Created immediately when FairyScope is built
  FairyScopeViewModel(
    this.create, {
    this.lazy = true,
  }) : viewModelType = T;
}
