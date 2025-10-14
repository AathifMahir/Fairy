/// Fairy - A lightweight MVVM framework for Flutter
///
/// Provides strongly-typed, reactive data binding without build_runner.
/// Combines reactive properties, command patterns, and dependency injection
/// with minimal boilerplate.
///
/// ## Learn Just 2 Widgets:
/// - **Bind** - Reactive data binding (`Bind` / `Bind.observer`)
/// - **Command** - User action binding (`Command` / `Command.withParam`)
///
/// ## Core Features:
// ignore: unintended_html_in_doc_comment
/// - **ObservableProperty<T>**: Typed, reactive properties for two-way binding
/// - **RelayCommand / AsyncRelayCommand**: Command pattern with canExecute logic
/// - **Auto-tracking**: `Bind.observer` automatically tracks accessed properties
/// - **Parameterized commands**: `Command.withParam` for actions with parameters
/// - **FairyLocator**: Global dependency injection
/// - **FairyScope**: Widget-scoped dependency injection with automatic disposal
///
/// ## Quick Start:
/// ```dart
/// // 1. Create a ViewModel
/// class CounterViewModel extends ObservableObject {
///   final count = ObservableProperty<int>(0);
///   late final increment = RelayCommand(() => count.value++);
///
///   // Properties and commands auto-disposed by super.dispose()
/// }
///
/// // 2. Provide it via FairyScope
/// FairyScope(
///   viewModel: (_) => CounterViewModel(),
///   child: MyApp(),
/// )
///
/// // 3. Bind in UI with just 2 widgets
/// 
/// // Data binding
/// Bind<CounterViewModel, int>(
///   selector: (vm) => vm.count.value,
///   builder: (ctx, value, update) => Text('$value'),
/// )
///
/// // Or use auto-tracking
/// Bind.observer<CounterViewModel>(
///   builder: (ctx, vm) => Text('${vm.count.value}'),
/// )
///
/// // Command binding
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
export 'src/extensions.dart' show FairyContextExtensions;
// Dependency injection
export 'src/locator/fairy_locator.dart' show FairyLocator;
export 'src/locator/fairy_scope.dart' show FairyScope;
export 'src/locator/fairy_resolver.dart' show Fairy;
// UI binding widgets
export 'src/ui/bind_widget.dart' show Bind;
export 'src/ui/bind_observer.dart'
    show BindObserver, BindObserver2, BindObserver3;
export 'src/ui/command_widget.dart' show Command, CommandWithParam;
// Utilities
export 'src/utils/equals.dart' show Equals;
export 'src/utils/lifecycle.dart' show Disposable, DisposeBag;
