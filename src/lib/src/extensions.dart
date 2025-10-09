import 'package:flutter/widgets.dart';
import 'core/observable.dart';
import 'core/command.dart';
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

// ========================================================================
// Observable Helper Extensions
// ========================================================================

/// Extension methods on [ObservableObject] for creating properties and commands with auto-disposal.
extension ObservableObjectExtensions on ObservableObject {
  /// Creates an [ObservableProperty] that will be auto-disposed with this ViewModel.
  ///
  /// This is the preferred way to create observable properties inside ViewModels.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   final counter = observableProperty<int>(0);
  ///   final name = observableProperty<String>('');
  /// }
  /// ```
  ObservableProperty<T> observableProperty<T>(T initialValue) {
    return ObservableProperty<T>(initialValue, parent: this);
  }

  /// Creates a [ComputedProperty] that will be auto-disposed with this ViewModel.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   final firstName = observableProperty<String>('');
  ///   final lastName = observableProperty<String>('');
  ///   late final fullName = computedProperty<String>(
  ///     () => '${firstName.value} ${lastName.value}',
  ///     [firstName, lastName],
  ///   );
  /// }
  /// ```
  ComputedProperty<T> computedProperty<T>(
    T Function() compute,
    List<Listenable> dependencies,
  ) {
    return ComputedProperty<T>(compute, dependencies, parent: this);
  }

  /// Creates a [RelayCommand] that will be auto-disposed with this ViewModel.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   late final save = relayCommand(_save);
  ///   
  ///   void _save() {
  ///     // Save logic
  ///   }
  /// }
  /// ```
  RelayCommand relayCommand(
    VoidCallback execute, {
    CanExecute? canExecute,
  }) {
    return RelayCommand(
      execute,
      canExecute: canExecute,
      parent: this,
    );
  }

  /// Creates an [AsyncRelayCommand] that will be auto-disposed with this ViewModel.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   late final load = asyncRelayCommand(_load);
  ///   
  ///   Future<void> _load() async {
  ///     // Load logic
  ///   }
  /// }
  /// ```
  AsyncRelayCommand asyncRelayCommand(
    Future<void> Function() execute, {
    CanExecute? canExecute,
  }) {
    return AsyncRelayCommand(
      execute,
      canExecute: canExecute,
      parent: this,
    );
  }

  /// Creates a [RelayCommandWithParam] that will be auto-disposed with this ViewModel.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   late final delete = relayCommandWithParam<String>(_delete);
  ///   
  ///   void _delete(String id) {
  ///     // Delete logic
  ///   }
  /// }
  /// ```
  RelayCommandWithParam<TParam> relayCommandWithParam<TParam>(
    void Function(TParam) execute, {
    bool Function(TParam)? canExecute,
  }) {
    return RelayCommandWithParam<TParam>(
      execute,
      canExecute: canExecute,
      parent: this,
    );
  }

  /// Creates an [AsyncRelayCommandWithParam] that will be auto-disposed with this ViewModel.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   late final loadUser = asyncRelayCommandWithParam<String>(_loadUser);
  ///   
  ///   Future<void> _loadUser(String userId) async {
  ///     // Load user logic
  ///   }
  /// }
  /// ```
  AsyncRelayCommandWithParam<TParam> asyncRelayCommandWithParam<TParam>(
    Future<void> Function(TParam) execute, {
    bool Function(TParam)? canExecute,
  }) {
    return AsyncRelayCommandWithParam<TParam>(
      execute,
      canExecute: canExecute,
      parent: this,
    );
  }
}