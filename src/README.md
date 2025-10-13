# Fairy

A lightweight MVVM framework for Flutter that provides strongly-typed, reactive data binding. Fairy combines reactive properties, command patterns, and dependency injection with minimal boilerplate.

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
  fairy: ^1.0.0-rc.1
```

### Basic Example

```dart
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

// 1. Create a ViewModel extending ObservableObject
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  late final incrementCommand = RelayCommand(() => counter.value++);
  late final addCommand = RelayCommandWithParam<int>((amount) => counter.value += amount);
  
  // Properties and commands auto-disposed by super.dispose()
}

// 2. Use FairyScope to provide the ViewModel
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FairyScope(
        viewModel: (_) => CounterViewModel(),
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
            // Option 1: Explicit binding (recommended for single properties)
            Bind<CounterViewModel, int>(
              selector: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
            
            // Option 2: Auto-tracking (convenient for multiple properties)
            Bind.observer<CounterViewModel>(
              builder: (context, vm) => Text('${vm.counter.value}'),
            ),
            
            // Command binding (non-parameterized)
            Command<CounterViewModel>(
              command: (vm) => vm.incrementCommand,
              builder: (context, execute, canExecute) {
                return ElevatedButton(
                  onPressed: canExecute ? execute : null,
                  child: Text('Increment'),
                );
              },
            ),
            
            // Command binding (parameterized)
            Command.param<CounterViewModel, int>(
              command: (vm) => vm.addCommand,
              parameter: 5,
              builder: (context, execute, canExecute) {
                return ElevatedButton(
                  onPressed: canExecute ? execute : null,
                  child: Text('Add 5'),
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

Your ViewModels extend `ObservableObject`:

```dart
class UserViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);
  
  // ✅ Properties auto-disposed by super.dispose()
  // No manual disposal needed!
}
```

**Auto-Disposal:** Properties and commands are automatically disposed when the parent ViewModel is disposed. See [Best Practices](#best-practices) for details.

### 2. ObservableProperty<T> - Reactive State

Type-safe properties that notify listeners when their value changes:

```dart
class MyViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  
  void someMethod() {
    // Modify value
    counter.value = 42;
    
    // Listen to changes (returns disposer function)
    final dispose = counter.propertyChanged(() {
      print('Counter changed: ${counter.value}');
    });
    
    // Later: remove listener
    dispose();  // ⚠️ Always call this to avoid memory leaks!
  }
}
```

> **⚠️ Memory Leak Warning:** Always capture and call the disposer returned by `propertyChanged()`. Failing to do so will cause memory leaks as the listener remains registered indefinitely. See [Best Practices](#best-practices) section for details.

### 3. Commands - Action Encapsulation

Commands encapsulate actions with optional validation:

```dart
class MyViewModel extends ObservableObject {
  final selectedItem = ObservableProperty<Item?>(null);
  
  late final saveCommand = RelayCommand(_save);
  late final deleteCommand = RelayCommand(
    _delete,
    canExecute: () => selectedItem.value != null,
  );
  
  late final VoidCallback _disposer;
  
  MyViewModel() {
    // Refresh command when dependencies change
    _disposer = selectedItem.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }
  
  @override
  void dispose() {
    _disposer();
    super.dispose();  // Auto-disposes properties and commands
  }
  
  void _save() {
    // Save logic
  }
  
  void _delete() {
    // Delete logic
  }
}
```

#### Async Commands

For asynchronous operations with automatic `isRunning` state:

```dart
class MyViewModel extends ObservableObject {
  late final fetchCommand = AsyncRelayCommand(_fetchData);
  
  Future<void> _fetchData() async {
    // fetchCommand.isRunning is automatically true
    await api.getData();
    // fetchCommand.isRunning automatically false
  }
}
```

#### Parameterized Commands

Commands that accept parameters (useful for item actions, delete operations, etc.):

```dart
class TodoViewModel extends ObservableObject {
  final todos = ObservableProperty<List<Todo>>([]);
  
  late final deleteTodoCommand = RelayCommandWithParam<String>(
    (id) => todos.value = todos.value.where((t) => t.id != id).toList(),
    canExecute: (id) => todos.value.any((t) => t.id == id),
  );
}

// In UI - use Command.param:
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteTodoCommand,
  parameter: todoId,
  builder: (context, execute, canExecute) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

#### Listening to Command Changes

Commands support listening to `canExecute` state changes, similar to how properties work:

```dart
class MyViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  
  late final saveCommand = RelayCommand(
    _save,
    canExecute: () => userName.value.isNotEmpty,
  );
  
  VoidCallback? _commandDisposer;
  
  MyViewModel() {
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
    super.dispose();  // Auto-disposes userName and saveCommand
  }
}
```

> **⚠️ Memory Leak Warning:** Always capture the disposer returned by `canExecuteChanged()`. Failing to call it will cause memory leaks. For UI binding, use the `Command` widget which handles this automatically.

### 4. Data Binding with `Bind`

The `Bind` widget handles reactive data binding. With just 2 widgets (`Bind` and `Command`), you're covering almost all your UI binding needs.

#### Explicit Binding (Recommended)

Use `Bind<TViewModel, TValue>` with an explicit selector for optimal performance:

```dart
// One-way binding (read-only)
Bind<UserViewModel, String>(
  selector: (vm) => vm.name.value,  // Returns String
  builder: (context, value, update) {
    return Text(value);  // update is null
  },
)

// Two-way binding (read-write)
Bind<UserViewModel, String>(
  selector: (vm) => vm.name,  // Returns ObservableProperty<String>
  builder: (context, value, update) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: update,  // update callback provided
    );
  },
)
```

#### Auto-Tracking with `Bind.observer`

For multiple properties or rapid prototyping, use `Bind.observer` which automatically tracks accessed properties:

```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  final age = ObservableProperty<int>(30);
}

// Auto-tracks all accessed properties - no manual selectors needed!
Bind.observer<UserViewModel>(
  builder: (context, vm) {
    return Column(
      children: [
        Text('Name: ${vm.firstName.value} ${vm.lastName.value}'),
        Text('Age: ${vm.age.value}'),
        // All three properties automatically tracked!
        // Widget rebuilds only when accessed properties change
      ],
    );
  },
)
```

**When to use `Bind.observer`:**
- Multiple related properties displayed together
- Complex UI with many data points
- Rapid prototyping and development
- When convenience outweighs micro-optimization

**Performance Note:** Explicit selectors are ~5-10% faster

### 5. Command Binding with `Command`

The `Command` widget binds commands to UI elements:

#### Non-Parameterized Commands

```dart
Command<UserViewModel>(
  command: (vm) => vm.saveCommand,
  builder: (context, execute, canExecute) {
    return ElevatedButton(
      onPressed: canExecute ? execute : null,  // Auto-disabled
      child: Text('Save'),
    );
  },
)
```

#### Parameterized Commands with `Command.param`

When your command needs parameters (e.g., item IDs, user input):

```dart
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteTodoCommand,
  parameter: todoId,
  builder: (context, execute, canExecute) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

### 6. Dependency Injection

Fairy provides two powerful DI patterns that can be used together:

#### Scoped DI with FairyScope

`FairyScope` provides widget-scoped ViewModels with automatic lifecycle management. It's flexible and can be used **anywhere** in your widget tree:

**Note**: ViewModels Registered Using `FairyScope` is not tied to Build Context but Uses Widget Tree for Dependency Lifecycle Management, Therefore setting `autoDispose: false` will keep the ViewModel alive until manually disposed. but by default it is `true`.

**At the app root (even above MaterialApp):**
```dart
void main() {
  runApp(
    FairyScope(
      viewModel: (_) => AppViewModel(),
      child: MyApp(),
    ),
  );
}

// Or wrap MaterialApp
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (_) => ThemeViewModel(),
      child: MaterialApp(
        home: HomePage(),
      ),
    );
  }
}
```

**At page level:**
```dart
FairyScope(
  viewModel: (_) => ProfileViewModel(userId: widget.userId),
  child: ProfilePage(),
)
```

**Nested scopes (parent-child relationship):**
```dart
FairyScope(
  viewModel: (_) => ParentViewModel(),
  child: Column(
    children: [
      FairyScope(
        viewModel: (_) => ChildViewModel(),
        child: ChildWidget(),
      ),
    ],
  ),
)
```

**Multiple ViewModels in one scope:**
```dart
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (_) => SettingsViewModel(),
    (_) => NotificationViewModel(),
  ],
  child: DashboardPage(),
)
```

**Accessing ViewModels:**
```dart
// In widgets
final userVM = Fairy.of<UserViewModel>(context);
final settingsVM = context.of<SettingsViewModel>();

// In ViewModels (dependency injection)

FairyLocator.instance.registerSingleton<ApiService>(ApiService());

FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (locator) => UserViewModel(
      api: locator.get<ApiService>(),  // Access previously registered service
    ),
    (locator) => SettingsViewModel(
      userVM: locator.get<UserViewModel>(),  // Access sibling VM
    )
  ],
  child: MyPage(),
)
```

**Auto-disposal:**
By default, FairyScope automatically disposes ViewModels when removed from the tree. You can control this:

```dart
FairyScope(
  viewModel: (_) => MyViewModel(),
  autoDispose: true,  // Default: auto-dispose when scope is removed
  child: MyPage(),
)

FairyScope(
  viewModel: (_) => SharedViewModel(),
  autoDispose: false,  // Keep alive, manual disposal required
  child: MyPage(),
)
```

#### Global DI with FairyLocator

For app-wide singletons like services:

```dart
// Register in main()
void main() {
  FairyLocator.instance.registerSingleton<ApiService>(ApiService());

  // Register singleton
  FairyLocator.instance.registerSingleton<AuthService>(AuthService());

  // Lazy singleton registration
  FairyLocator.instance.registerLazySingleton<DatabaseService>(() => DatabaseService());
  
  // Async singleton registration
  await FairyLocator.instance.registerSingletonAsync<ConfigService>(
    () async => await ConfigService.load(),
  );

  // Register transient (new instance each time) or else we call factory registration
  FairyLocator.instance.registerTransient<TempService>(() => TempService());
  
  runApp(MyApp());
}

// Access anywhere
final api = FairyLocator.instance.get<ApiService>();

// Or use in FairyScope
// locator parameter provides access to registered services inside FairyScope
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    api: locator.get<ApiService>(),
    auth: locator.get<AuthService>(),
  ),
  child: ProfilePage(),
)

// Cleanup (usually not needed for app-wide services)
FairyLocator.instance.unregister<ApiService>();
```

#### Resolution Order

`Fairy.of<T>(context)` and the `locator` parameter in FairyScope check:
1. **Current FairyScope** - ViewModels registered in the nearest scope
2. **Parent FairyScopes** - ViewModels from ancestor scopes (walking up the tree)
3. **FairyLocator** - Global singleton registry
4. **Throws exception** if not found

This design allows:
- ✅ Child ViewModels to access parent ViewModels
- ✅ Any ViewModel to access global services
- ✅ Proper scoping and lifecycle management
- ✅ Compile-time type safety

**Note:** The API follows Flutter's convention (e.g., `Theme.of(context)`, `MediaQuery.of(context)`) for familiar and idiomatic usage.

## Advanced Features

### ComputedProperty

Derived properties that depend on other ObservableProperties:

```dart
class MyViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
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

final user = ObservableProperty<User>(User('1', 'Alice'));
```

## Best Practices

### 1. Auto-Disposal

**ObservableProperty, ComputedProperty, and Commands are automatically disposed** when the parent ViewModel is disposed:

```dart
class UserViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);
  late final saveCommand = RelayCommand(_save);
  late final fullInfo = ComputedProperty<String>(
    () => '${userName.value}, age ${age.value}',
    [userName, age],
  );
  
  void _save() { /* ... */ }
  
  // ✅ All properties and commands auto-disposed by super.dispose()
  // No manual disposal needed!
}
```

**Exception: Nested ViewModels require manual disposal:**

```dart
class ParentViewModel extends ObservableObject {
  final data = ObservableProperty<String>('');
  
  // Nested ViewModels require manual disposal
  late final childVM = ChildViewModel();  // ⚠️ Manual disposal required
  
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
class MyViewModel extends ObservableObject {
  final selectedItem = ObservableProperty<Item?>(null);
  late final deleteCommand = RelayCommand(
    _delete,
    canExecute: () => selectedItem.value != null,
  );
  late final editCommand = RelayCommand(
    _edit,
    canExecute: () => selectedItem.value != null,
  );
  
  VoidCallback? _selectedItemDisposer;
  
  MyViewModel() {
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
}
```

### 3. Always Capture Disposers from Manual Listener Calls ⚠️

**WARNING:** While properties and commands are auto-disposed, **manual listeners are NOT**. Not capturing the disposer returned by `propertyChanged()` or `canExecuteChanged()` will cause **memory leaks**!

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
- Auto-disposal only handles property/command cleanup
- When `propertyChanged()` or `canExecuteChanged()` is called directly, it registers a listener
- The listener stays registered until explicitly removed via the disposer
- Without calling the disposer, the listener (and any objects it captures) remain in memory
- This is especially problematic if the `ViewModel` outlives the widget (e.g., global singleton)

**Best practice:** Use `Bind` or `Command` widgets for 99% of UI scenarios. Only use `propertyChanged()` or `canExecuteChanged()` directly in `StatefulWidget` when you have a specific reason, and **always** capture and call the disposer.

### 4. Use Scoped DI for Page-Level ViewModels

```dart
// ✅ Good: Scoped ViewModel auto-disposed
FairyScope(
  viewModel: (_) => UserProfileViewModel(userId: widget.userId),
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

### 6. Choose the Right Binding Approach

**For single properties:** Use explicit `Bind<TViewModel, TValue>` for optimal performance:

```dart
// ✅ Best for single properties
Bind<MyVM, int>(
  selector: (vm) => vm.counter,  // Returns ObservableProperty<int>
  builder: (context, value, update) => Text('$value'),
)
```

**For multiple properties:** Use `Bind.observer` for convenience with excellent selective efficiency:

```dart
// ✅ Best for multiple properties
Bind.observer<UserViewModel>(
  builder: (context, vm) {
    return Text('${vm.firstName.value} ${vm.lastName.value}');
    // Both properties automatically tracked!
  },
)
```

**Avoid one-way binding:** Returning raw values requires manual change notification:

```dart
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
  
  vm.dispose(); // Auto-disposes all properties and commands
});
```

Widget tests work seamlessly with `FairyScope` and both `Bind` variants:

```dart
testWidgets('counter increments on button tap', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FairyScope(
        viewModel: (_) => CounterViewModel(),
        child: CounterPage(),
      ),
    ),
  );
  
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  expect(find.text('1'), findsOneWidget);
});

testWidgets('Bind.observer rebuilds on property change', (tester) async {
  final vm = UserViewModel();
  
  await tester.pumpWidget(
    MaterialApp(
      home: FairyScope(
        viewModel: (_) => vm,
        child: Bind.observer<UserViewModel>(
          builder: (context, vm) => Text('${vm.firstName.value}'),
        ),
      ),
    ),
  );
  
  expect(find.text('John'), findsOneWidget);
  
  vm.firstName.value = 'Jane';
  await tester.pump();
  
  expect(find.text('Jane'), findsOneWidget);
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

BSD 3-Clause License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
