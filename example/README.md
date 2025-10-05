# Fairy Counter Example

This example demonstrates the core features of the Fairy MVVM framework through a simple counter application.

## Features Demonstrated

### 1. **MVVM Architecture**
- Clear separation between View (`CounterPage`) and ViewModel (`CounterViewModel`)
- ViewModel contains all business logic and state
- View is purely declarative, no business logic

### 2. **Reactive Properties**
```dart
final counter = ObservableProperty<int>(0);
```
- Type-safe property that notifies listeners on changes
- Automatically triggers UI updates when value changes

### 3. **Command Pattern**
```dart
late final RelayCommand incrementCommand;
late final RelayCommand decrementCommand;
```
- Encapsulates actions with automatic `canExecute` validation
- Decrement button automatically disables when counter reaches 0
- Commands can be refreshed when dependencies change

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
- Child widgets access ViewModel through `ViewModelLocator`

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Best Practices Shown

1. **Property Management**: Always dispose `ObservableProperty` in `dispose()`
2. **Command Dependencies**: Refresh commands when their `canExecute` conditions change
3. **Scoped Lifecycle**: Use `FairyScope.create` for widget-scoped ViewModels
4. **Type Safety**: Leverage generics (`Bind<TViewModel, TValue>`) for compile-time safety
5. **Declarative UI**: Views contain only widget composition, no business logic

## Learning Path

1. **Start Here**: Understand the ViewModel structure in `main.dart` (CounterViewModel)
2. **Data Binding**: See how `Bind` widget connects property to UI
3. **Commands**: Observe `Command` widget binding actions to buttons
4. **Reactive Logic**: Notice how `counter.listen()` triggers `decrementCommand.refresh()`
5. **Disposal**: Check `dispose()` method for proper cleanup

## Extending the Example

Try these exercises to deepen your understanding:

1. Add an `AsyncRelayCommand` for a simulated API call
2. Implement `ComputedProperty` to show "Even/Odd" based on counter
3. Add a text field bound to counter using two-way binding's `update` callback
4. Create a second ViewModel with global registration using `FairyLocator`
5. Add a `RelayCommandWithParam<int>` to add custom increments
