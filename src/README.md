# Fairy

A lightweight MVVM framework for Flutter that provides strongly-typed, reactive data binding without build_runner. Fairy combines reactive properties, command patterns, and dependency injection with minimal boilerplate.

## Features

- ✨ **No Code Generation**: Runtime-only implementation, no build_runner required
- 🎯 **Type-Safe Binding**: Strongly-typed reactive properties and commands with compile-time safety
- 🔄 **Automatic UI Updates**: Data binding that automatically updates your UI when state changes
- ⚡ **Command Pattern**: Encapsulate actions with built-in `canExecute` validation
- 🏗️ **Dependency Injection**: Both global singleton and widget-scoped DI patterns
- 🧩 **Minimal Boilerplate**: Clean, intuitive API that gets out of your way
- 📦 **Lightweight**: Small footprint with zero external dependencies (except Flutter)

## Quick Start

### Installation

Add Fairy to your `pubspec.yaml`:

```yaml
dependencies:
  fairy: ^0.6.0
```

### Basic Example

```dart
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

// 1. Create a ViewModel extending ObservableObject
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0, parent: this);
  late final RelayCommand incrementCommand;
  
  CounterViewModel() {
    incrementCommand = RelayCommand(
      execute: () => counter.value++,
      parent: this,
    );
  }
  
  // Properties and commands auto-disposed by super.dispose()
}

// 2. Use FairyScope to provide the ViewModel
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FairyScope(
        create: () => CounterViewModel(),
        child: CounterPage(),
      ),
    );
  }
}

// 3. Bind your UI to ViewModel properties and commands
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Data binding - automatically updates when counter changes
            Bind<CounterViewModel, int>(
              selector: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
            
            // Command binding - automatically disabled when canExecute is false
            Command<CounterViewModel>(
              command: (vm) => vm.incrementCommand,
              builder: (context, execute, canExecute) {
                return ElevatedButton(
                  onPressed: canExecute ? execute : null,
                  child: Text('Increment'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

## Core Concepts

### 1. ObservableObject - ViewModel Base Class

Your ViewModels extend `ObservableObject` which extends Flutter's `ChangeNotifier`:

```dart
class UserViewModel extends ObservableObject {
  final name = ObservableProperty<String>('', parent: this);
  final age = ObservableProperty<int>(0, parent: this);
  
  // ✅ Properties auto-disposed by super.dispose()
  // No manual disposal needed!
}
```

**Auto-Disposal:** Properties and commands created with the `parent` parameter are automatically disposed when the parent ViewModel is disposed. Pass `parent: this` to enable auto-disposal. See [Best Practices](#best-practices) for details.

### 2. ObservableProperty<T> - Reactive State

Type-safe properties that notify listeners when their value changes:

```dart
// With auto-disposal (recommended)
final counter = ObservableProperty<int>(0, parent: this);

// Modify value
counter.value = 42;

// Listen to changes (returns disposer function)
final dispose = counter.propertyChanged(() => print('Counter changed: ${counter.value}'));

// Later: remove listener
dispose();  // ⚠️ Always call this to avoid memory leaks!
```

> **⚠️ Memory Leak Warning:** Always capture and call the disposer returned by `propertyChanged()`. Failing to do so will cause memory leaks as the listener remains registered indefinitely. See [Best Practices](#best-practices) section for details.

### 3. Commands - Action Encapsulation

Commands encapsulate actions with optional validation:

```dart
// Simple command
late final RelayCommand saveCommand;

// Command with canExecute validation
late final RelayCommand deleteCommand;
late final VoidCallback _disposer;

MyViewModel() {
  saveCommand = RelayCommand(
    execute: _save,
    parent: this,
  );
  
  deleteCommand = RelayCommand(
    execute: _delete,
    canExecute: () => selectedItem.value != null,
    parent: this,
  );
  
  // Refresh command when dependencies change
  _disposer = selectedItem.propertyChanged(() => deleteCommand.notifyCanExecuteChanged());
}

@override
void dispose() {
  _disposer();
  super.dispose();
}

void _save() {
  // Save logic
}

void _delete() {
  // Delete logic
}
```

#### Async Commands

For asynchronous operations with automatic `isRunning` state:

```dart
late final AsyncRelayCommand fetchCommand;

MyViewModel() {
  fetchCommand = AsyncRelayCommand(
    execute: _fetchData,
    parent: this,
  );
}

Future<void> _fetchData() async {
  // fetchCommand.isRunning is automatically true
  await api.getData();
  // fetchCommand.isRunning automatically false
}
```

#### Parameterized Commands

Commands that accept parameters:

```dart
late final RelayCommandWithParam<int> addValueCommand;

MyViewModel() {
  addValueCommand = RelayCommandWithParam<int>(
    execute: (value) => counter.value += value,
    canExecute: (value) => value > 0,
    parent: this,
  );
}

// In UI:
CommandWithParam<MyViewModel, int>(
  command: (vm) => vm.addValueCommand,
  parameter: 5,
  builder: (context, execute, canExecute) {
    return ElevatedButton(
      onPressed: canExecute ? execute : null,
      child: Text('Add 5'),
    );
  },
)
```

#### Listening to Command Changes

Commands support listening to `canExecute` state changes, similar to how properties work:

```dart
late final RelayCommand saveCommand;
VoidCallback? _commandDisposer;

MyViewModel() {
  saveCommand = RelayCommand(
    execute: _save,
    canExecute: () => userName.value.isNotEmpty,
    parent: this,
  );
  
  // Listen to canExecute changes
  _commandDisposer = saveCommand.canExecuteChanged(() {
    print('Save command canExecute changed: ${saveCommand.canExecute}');
  });
}

void _save() {
  // Save logic
}

@override
void dispose() {
  _commandDisposer?.call();
  super.dispose();
}
```

> **⚠️ Memory Leak Warning:** Always capture the disposer returned by `canExecuteChanged()`. Failing to call it will cause memory leaks. For UI binding, use the `Command` widget which handles this automatically.

### 4. Data Binding

The `Bind` widget automatically detects one-way vs two-way binding:

#### Two-Way Binding

When selector returns `ObservableProperty<T>`, you get two-way binding with an `update` callback:

```dart
Bind<UserViewModel, String>(
  selector: (vm) => vm.name,  // Returns ObservableProperty<String>
  builder: (context, value, update) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: update,  // update is non-null for two-way binding
    );
  },
)
```

#### One-Way Binding

When selector returns raw `T`, you get one-way binding (read-only):

```dart
Bind<UserViewModel, String>(
  selector: (vm) => vm.name.value,  // Returns String
  builder: (context, value, update) {
    return Text(value);  // update is null for one-way binding
  },
)
```

**Note**: For one-way binding with raw values, the ViewModel must explicitly call `onPropertyChanged()` when values change. It's often simpler to use two-way binding even for read-only scenarios.

### 5. Command Binding

The `Command` widget binds commands to UI elements:

```dart
Command<UserViewModel>(
  command: (vm) => vm.saveCommand,
  builder: (context, execute, canExecute) {
    return ElevatedButton(
      onPressed: canExecute ? execute : null,  // Auto-disabled
      child: saveCommand.isRunning 
        ? CircularProgressIndicator() 
        : Text('Save'),
    );
  },
)
```

### 6. Dependency Injection

Fairy provides two DI patterns:

#### Scoped DI with FairyScope

Widget-scoped ViewModels that are automatically disposed:

```dart
FairyScope(
  create: () => CounterViewModel(),  // Auto-disposed when removed
  child: MyWidget(),
)
```

#### Global DI with FairyLocator

Singleton registration for app-wide services:

```dart
// Register
FairyLocator.instance.registerSingleton<ApiService>(ApiService());

// Access
final api = FairyLocator.instance.get<ApiService>();

// Cleanup
FairyLocator.instance.unregister<ApiService>();
```

#### Resolution Order

`Fairy.of<T>(context)` checks:
1. Nearest `FairyScope` in widget tree
2. `FairyLocator` global registry
3. Throws exception if not found

**Note:** The API follows Flutter's convention (e.g., `Theme.of(context)`, `MediaQuery.of(context)`) for familiar and idiomatic usage.

## Advanced Features

### ComputedProperty

Derived properties that depend on other ObservableProperties:

```dart
final firstName = ObservableProperty<String>('John', parent: this);
final lastName = ObservableProperty<String>('Doe', parent: this);

late final ComputedProperty<String> fullName;

MyViewModel() {
  fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
    parent: this,
  );
}
```

### Custom Value Equality

ObservableProperty uses `!=` for equality checking. For custom types, override the `==` operator:

```dart
class User {
  final String id;
  final String name;
  
  User(this.id, this.name);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

final user = ObservableProperty<User>(
  User('1', 'Alice'),
  parent: this,
);
```

## Best Practices

### 1. Auto-Disposal with Parent Parameter

**ObservableProperty, ComputedProperty, and Commands are automatically disposed** when you pass `parent: this`:

```dart
class UserViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('', parent: this);
  final age = ObservableProperty<int>(0, parent: this);
  late final RelayCommand saveCommand;
  late final ComputedProperty<String> fullInfo;
  
  UserViewModel() {
    saveCommand = RelayCommand(
      execute: _save,
      parent: this,
    );
    
    fullInfo = ComputedProperty<String>(
      () => '${userName.value}, age ${age.value}',
      [userName, age],
      parent: this,
    );
  }
  
  void _save() { /* ... */ }
  
  // ✅ All properties and commands auto-disposed by super.dispose()
  // No manual disposal needed!
}
```

**Exception: Nested ViewModels require manual disposal:**

```dart
class ParentViewModel extends ObservableObject {
  final data = ObservableProperty<String>('', parent: this);  // ✅ Auto-disposed
  late final childVM = ChildViewModel();                      // ⚠️ Manual disposal required
  
  @override
  void dispose() {
    childVM.dispose();  // Must manually dispose nested ViewModels
    super.dispose();    // Auto-disposes properties and commands
  }
}
```

This prevents double-disposal issues when nested ViewModels are shared or managed externally.

### 2. Refresh Commands on Dependency Changes

When a command's `canExecute` depends on other properties, refresh the command when those properties change:

```dart
final selectedItem = ObservableProperty<Item?>(null, parent: this);
late final RelayCommand deleteCommand;
late final RelayCommand editCommand;
VoidCallback? _selectedItemDisposer;

MyViewModel() {
  deleteCommand = RelayCommand(
    execute: _delete,
    canExecute: () => selectedItem.value != null,
    parent: this,
  );
  
  editCommand = RelayCommand(
    execute: _edit,
    canExecute: () => selectedItem.value != null,
    parent: this,
  );
  
  // When canExecute depends on other state
  _selectedItemDisposer = selectedItem.propertyChanged(() {
    deleteCommand.notifyCanExecuteChanged();
    editCommand.notifyCanExecuteChanged();
  });
}

void _delete() { /* ... */ }
void _edit() { /* ... */ }

@override
void dispose() {
  _selectedItemDisposer?.call();
  super.dispose();  // selectedItem and commands auto-disposed
}
```

### 3. Always Capture Disposers from Manual Listener Calls ⚠️

**WARNING:** While properties and commands are auto-disposed with `parent` parameter, **manual listeners are NOT**. Not capturing the disposer returned by `propertyChanged()` or `canExecuteChanged()` will cause **memory leaks**!

```dart
// ❌ MEMORY LEAK: Disposer is ignored
viewModel.propertyChanged(() {
  print('changed');
});
command.canExecuteChanged(() {
  print('canExecute changed');
});
// Listeners stay in memory forever, even after widget disposal!

// ✅ CORRECT: Capture and call disposers
class _MyWidgetState extends State<MyWidget> {
  late VoidCallback _disposePropertyListener;
  late VoidCallback _disposeCommandListener;
  
  @override
  void initState() {
    super.initState();
    final vm = Fairy.of<MyViewModel>(context);
    
    // Store the disposers
    _disposePropertyListener = vm.counter.propertyChanged(() {
      setState(() {});
    });
    
    _disposeCommandListener = vm.saveCommand.canExecuteChanged(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _disposePropertyListener(); // Clean up listeners
    _disposeCommandListener();
    super.dispose();
  }
}

// ✅ BEST: Use Bind/Command widgets (handle lifecycle automatically)
Bind<MyViewModel, int>(
  selector: (vm) => vm.counter,
  builder: (context, value, update) => Text('$value'),
)

Command<MyViewModel>(
  command: (vm) => vm.saveCommand,
  builder: (context, execute, canExecute) => 
    ElevatedButton(onPressed: canExecute ? execute : null, child: Text('Save')),
)
```

**Why memory leaks still occur with manual listeners:**
- Auto-disposal only handles property/command cleanup (when `parent` is provided)
- When `propertyChanged()` or `canExecuteChanged()` is called directly, it registers a listener with the `ChangeNotifier`
- The listener stays registered until explicitly removed via the disposer
- Without calling the disposer, the listener (and any objects it captures) remain in memory
- This is especially problematic if the `ViewModel` outlives the widget (e.g., global singleton)

**Best practice:** Use `Bind` or `Command` widgets for 99% of UI scenarios. Only use `propertyChanged()` or `canExecuteChanged()` directly in `StatefulWidget` when you have a specific reason, and **always** capture and call the disposer.

### 4. Use Scoped DI for Page-Level ViewModels

```dart
// ✅ Good: Scoped ViewModel auto-disposed
FairyScope(
  create: () => UserProfileViewModel(userId: widget.userId),
  child: UserProfilePage(),
)

// ❌ Avoid: Manual lifecycle management
class _PageState extends State<Page> {
  late final vm = UserProfileViewModel();
  
  @override
  void dispose() {
    vm.dispose();  // Easy to forget!
    super.dispose();
  }
}
```

### 5. Use Global DI for App-Wide Services

```dart
// Register in main()
void main() {
  FairyLocator.instance.registerSingleton<ApiService>(ApiService());
  FairyLocator.instance.registerSingleton<AuthService>(AuthService());
  runApp(MyApp());
}
```

### 6. Prefer Two-Way Binding for Simplicity

Even for read-only scenarios, using two-way binding (returning `ObservableProperty`) is simpler than one-way binding (returning raw values):

```dart
// ✅ Simpler: Two-way binding
Bind<MyVM, int>(
  selector: (vm) => vm.counter,  // Returns ObservableProperty<int>
  builder: (context, value, update) => Text('$value'),
)

// ❌ More complex: One-way binding requires ViewModel.onPropertyChanged()
Bind<MyVM, int>(
  selector: (vm) => vm.counter.value,  // Returns int
  builder: (context, value, _) => Text('$value'),
)
```

## Example

See the [example](../example) directory for a complete counter app demonstrating:
- MVVM architecture
- Reactive properties
- Command pattern with canExecute
- Data and command binding
- Scoped dependency injection

## Testing

Fairy is designed for testability:

```dart
test('increment updates counter', () {
  final vm = CounterViewModel();
  
  expect(vm.counter.value, 0);
  
  vm.incrementCommand.execute();
  
  expect(vm.counter.value, 1);
  
  vm.dispose(); // Auto-disposes all properties and commands with parent parameter
});
```

Widget tests work seamlessly with `FairyScope`:

```dart
testWidgets('counter increments on button tap', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FairyScope(
        create: () => CounterViewModel(),
        child: CounterPage(),
      ),
    ),
  );
  
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  expect(find.text('1'), findsOneWidget);
});
```

## Architecture Guidelines

### ViewModel Responsibilities

✅ **DO:**
- Contain business logic
- Manage state with ObservableProperty
- Expose commands for user actions
- Coordinate with services/repositories

❌ **DON'T:**
- Reference widgets or BuildContext
- Perform navigation
- Contain UI logic or styling

### View Responsibilities

✅ **DO:**
- Purely declarative widget composition
- Bind to ViewModel properties and commands
- Handle navigation

❌ **DON'T:**
- Contain business logic
- Directly modify application state
- Perform data validation

## Comparison to Other Patterns

| Feature | Fairy | Provider | Riverpod | GetX | BLoC |
|---------|-------|----------|----------|------|------|
| Code Generation | ❌ | ❌ | ✅ | ❌ | ❌ |
| Type Safety | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Boilerplate | Low | Low | Medium | Low | High |
| Learning Curve | Low | Low | Medium | Low | Medium |
| Command Pattern | ✅ | ❌ | ❌ | ❌ | ❌ |
| Two-Way Binding | ✅ | ❌ | ❌ | ✅ | ❌ |

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
