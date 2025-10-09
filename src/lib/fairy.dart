/// Fairy - A lightweight MVVM framework for Flutter
///
/// Provides strongly-typed, reactive data binding without build_runner.
/// Combines reactive properties, command patterns, and dependency injection
/// with minimal boilerplate.
///
/// ## Core Features:
/// - **ObservableProperty<T>**: Typed, reactive properties for two-way binding
/// - **RelayCommand / AsyncRelayCommand**: Command pattern with canExecute logic
/// - **Bind**: Auto-detecting one-way vs two-way binding widget
/// - **Command**: Bind commands to UI with automatic canExecute reactivity
/// - **FairyLocator**: Global dependency injection
/// - **FairyScope**: Widget-scoped dependency injection with automatic disposal
///
/// ## Quick Start:
/// ```dart
/// // 1. Create a ViewModel
/// class CounterViewModel extends ObservableObject {
///   final count = ObservableProperty<int>(0, parent: this);
///   late final RelayCommand increment;
///
///   CounterViewModel() {
///     increment = RelayCommand(
///       execute: () => count.value++,
///       parent: this,
///     );
///   }
///
///   // Properties and commands auto-disposed by super.dispose()
/// }
///
/// // 2. Provide it via FairyScope
/// FairyScope(
///   create: () => CounterViewModel(),
///   child: MyApp(),
/// )
///
/// // 3. Bind in UI
/// Bind<CounterViewModel, int>(
///   selector: (vm) => vm.count,
///   builder: (ctx, value, update) => Text('$value'),
/// )
///
/// Command<CounterViewModel>(
///   command: (vm) => vm.increment,
///   builder: (ctx, execute, canExecute) =>
///     ElevatedButton(onPressed: execute, child: Text('+')),
/// )
/// ```
library;

export 'src/core/command.dart'
    show
        RelayCommand,
        AsyncRelayCommand,
        RelayCommandWithParam,
        AsyncRelayCommandWithParam,
        CanExecute;
// Core primitives
export 'src/core/observable.dart'
    show ObservableObject, ObservableProperty, ComputedProperty;
// Extensions
export 'src/extensions.dart'
    show FairyContextExtensions, ObservableObjectExtensions;
// Dependency injection
export 'src/locator/fairy_locator.dart' show FairyLocator;
export 'src/locator/fairy_scope.dart' show FairyScope;
export 'src/locator/fairy_resolver.dart' show Fairy;
// UI binding widgets
export 'src/ui/bind_widget.dart' show Bind;
export 'src/ui/command_widget.dart' show Command, CommandWithParam;
// Utilities
export 'src/utils/equals.dart' show listEquals, mapEquals, setEquals;
export 'src/utils/lifecycle.dart' show Disposable, DisposeBag;
