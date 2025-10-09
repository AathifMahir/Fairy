# Fairy Counter Example

This example demonstrates the core features of the Fairy MVVM framework through a simple counter application.

## Features Demonstrated

### 1. **MVVM Architecture**
- Clear separation between View (`CounterPage`) and ViewModel (`CounterViewModel`)
- ViewModel contains all business logic and state
- View is purely declarative, no business logic

### 2. **Reactive Properties**
```dart
late final ObservableProperty<int> counter;

CounterViewModel() {
  counter = ObservableProperty<int>(0, parent: this);
}
```
- Type-safe property that notifies listeners on changes
- Automatically triggers UI updates when value changes
- Auto-disposed when parent ViewModel is disposed (via `parent` parameter)

### 3. **Command Pattern**
```dart
late final RelayCommand incrementCommand;
late final RelayCommand decrementCommand;

CounterViewModel() {
  incrementCommand = RelayCommand(
    execute: _increment,
    parent: this,
  );
  
  decrementCommand = RelayCommand(
    execute: _decrement,
    canExecute: () => counter.value > 0,
    parent: this,
  );
}
```
- Encapsulates actions with automatic `canExecute` validation
- Decrement button automatically disables when counter reaches 0
- Commands use named parameters: `execute:`, `canExecute:`, `parent:`
- Commands can be refreshed when dependencies change using `notifyCanExecuteChanged()`
- Auto-disposed when parent ViewModel is disposed (via `parent` parameter)

### 4. **Data Binding**
```dart
Bind<CounterViewModel, int>(
  selector: (vm) => vm.counter,
  builder: (context, value, update) {
    return Text('$value');
  },
)
```
- Two-way binding to `ObservableProperty`
- UI automatically updates when property changes
- No manual subscription management needed

### 5. **Command Binding**
```dart
Command<CounterViewModel>(
  command: (vm) => vm.decrementCommand,
  builder: (context, execute, canExecute) {
    return ElevatedButton(
      onPressed: canExecute ? execute : null,
      child: const Text('Decrement'),
    );
  },
)
```
- Commands bind to UI elements
- `canExecute` state automatically reflects in button enabled/disabled state
- Execute callback invokes command action

### 6. **Dependency Injection**
```dart
FairyScope(
  create: () => CounterViewModel(),
  child: const CounterPage(),
)
```
- Scoped DI with automatic ViewModel disposal
- ViewModel automatically disposed when `FairyScope` is removed from tree
- Child widgets access ViewModel through `Fairy` resolver or `Bind`/`Command` widgets

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Best Practices Shown

1. **Auto-Disposal with Parent Parameter**: Properties and commands automatically disposed with parent ViewModel (pass `parent: this`)
2. **Named Parameters**: All commands use named parameters for clarity (`execute:`, `canExecute:`, `parent:`)
3. **Command Dependencies**: Refresh commands when their `canExecute` conditions change using `notifyCanExecuteChanged()`
4. **Scoped Lifecycle**: Use `FairyScope.create` for widget-scoped ViewModels
5. **Type Safety**: Leverage generics (`Bind<TViewModel, TValue>`) for compile-time safety
6. **Declarative UI**: Views contain only widget composition, no business logic
7. **Nested ViewModels**: Manual disposal required for nested `ObservableObject` instances

## Learning Path

1. **Start Here**: Understand the ViewModel structure in `main.dart` (CounterViewModel)
2. **Data Binding**: See how `Bind` widget connects property to UI
3. **Commands**: Observe `Command` widget binding actions to buttons
4. **Reactive Logic**: Notice how `counter.propertyChanged()` triggers `decrementCommand.notifyCanExecuteChanged()`
5. **Auto-Disposal**: Properties and commands are automatically cleaned up when `parent: this` is provided

## Extending the Example

Try these exercises to deepen your understanding:

1. Add an `AsyncRelayCommand` for a simulated API call
2. Implement `ComputedProperty` to show "Even/Odd" based on counter
3. Add a text field bound to counter using two-way binding's `update` callback
4. Create a second ViewModel with global registration using `FairyLocator`
5. Add a `RelayCommandWithParam<int>` to add custom increments
