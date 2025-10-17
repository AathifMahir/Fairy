<div align="center">
  <img src="logo.png" alt="Fairy Logo" width="300"/>
</div>

A lightweight MVVM framework for Flutter that provides strongly-typed, reactive data binding. Fairy combines reactive properties, command patterns, and dependency injection with minimal boilerplate.

## Design Philosophy

**Simplicity Over Complexity** - Fairy is built around the principle that state management should be simple and intuitive. With just a **few widgets and types**, you have everything you need for most use cases. This simplicity-first approach is reflected throughout the entire library design, making it easy to learn, easy to use, and easy to maintain.

## Features

- 🎓 **Few Widgets to Learn**: `Bind` for data, `Command` for actions - covers almost everything
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
  fairy: ^1.1.1
```

### Basic Example

```dart
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

// 1. Create a ViewModel extending ObservableObject
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  final multiplier = ObservableProperty<int>(2);
  late final incrementCommand = RelayCommand(() => counter.value++);
  late final addCommand = RelayCommandWithParam<int>((amount) => counter.value += amount);
  
  // Properties and commands auto-disposed by super.dispose()
}

// 2. Use FairyScope to provide the ViewModel
// Recommended: At app root for app-wide ViewModels
void main() {
  runApp(
    FairyScope(
      viewModel: (_) => CounterViewModel(),
      child: MyApp(),
    ),
  );
}

// Or anywhere in your widget tree (page-level, feature-level, etc.)
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
            
            // Option 2: Auto Binding for multiple properties
            Bind.viewModel<CounterViewModel>(
              builder: (context, vm) => Text('Count: ${vm.counter.value} × ${vm.multiplier.value}'),
            ),
            
            // Command binding (non-parameterized)
            Command<CounterViewModel>(
              command: (vm) => vm.incrementCommand,
              builder: (context, execute, canExecute, isRunning) {
                return ElevatedButton(
                  onPressed: canExecute ? execute : null,
                  child: Text('Increment'),
                );
              },
            ),
            
            // Command binding (parameterized)
            Command.param<CounterViewModel, int>(
              command: (vm) => vm.addCommand,
              parameter: () => 5,
              builder: (context, execute, canExecute, isRunning) {
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
  
  void increment() {
    // Just modify the value - that's it! 
    // ObservableProperty automatically notifies listeners (like Bind widgets)
    counter.value++;
  }
  
  void reset() {
    counter.value = 0;  // Automatic notification on change
  }
}
```

**Optional: Manual Change Subscription**

You can manually subscribe to changes if needed (e.g., for logging, analytics, or side effects):

```dart
class MyViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  late final VoidCallback disposePropertyChanges;
  
  MyViewModel() {
    // Optional: Subscribe to changes for side effects
    disposePropertyChanges = counter.propertyChanged(() {
      print('Counter changed: ${counter.value}');
      // Maybe log analytics, trigger side effects, etc.
    });
  }
  
  @override
  void dispose() {
    disposePropertyChanges();  // ⚠️ Always call to avoid memory leaks!
    super.dispose();  // Auto-disposes counter
  }
}
```

> **⚠️ Memory Leak Warning:** Always capture and call the disposer returned by `propertyChanged()`. Failing to do so will cause memory leaks as the listener remains registered indefinitely. For UI binding, use `Bind` widgets which handle lifecycle automatically.

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
  
  late final VoidCallback disposePropertyChanges;
  
  MyViewModel() {
    // Refresh command's canExecute when selectedItem changes
    disposePropertyChanges = selectedItem.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }
  
  @override
  void dispose() {
    disposePropertyChanges();
    super.dispose();  // Auto-disposes selectedItem, saveCommand, deleteCommand
  }
  
  void _save() {
    // Save logic - Command handles execution automatically
  }
  
  void _delete() {
    // Delete logic
  }
}
```

**Optional: Manual Command Change Subscription**

Commands support manual subscription to `canExecute` state changes for advanced scenarios (e.g., analytics, debugging):

```dart
class MyViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  
  late final saveCommand = RelayCommand(
    _save,
    canExecute: () => userName.value.isNotEmpty,
  );
  
  late final VoidCallback disposePropertyChanges;
  late final VoidCallback disposeCommandChanges;
  
  MyViewModel() {
    // Keep command's canExecute in sync with userName
    disposePropertyChanges = userName.propertyChanged(() {
      saveCommand.notifyCanExecuteChanged();
    });
    
    // Optional: Subscribe to canExecute changes for side effects
    disposeCommandChanges = saveCommand.canExecuteChanged(() {
      print('Save enabled: ${saveCommand.canExecute}');
      // Maybe update analytics, show hints, etc.
    });
  }
  
  void _save() {
    // Save logic
  }
  
  @override
  void dispose() {
    disposePropertyChanges();
    disposeCommandChanges();
    super.dispose();  // Auto-disposes userName and saveCommand
  }
}
```

> **⚠️ Memory Leak Warning:** Always capture disposers returned by `propertyChanged()` and `canExecuteChanged()`. Failing to call them will cause memory leaks. For UI binding, use `Command` widget which handles lifecycle automatically.

#### Async Commands

Async commands automatically track execution state with `isRunning`, preventing concurrent execution and enabling easy loading indicators:

```dart
class MyViewModel extends ObservableObject {
  late final fetchCommand = AsyncRelayCommand(_fetchData);
  
  Future<void> _fetchData() async {
    // fetchCommand.isRunning is automatically true
    await api.getData();
    // fetchCommand.isRunning automatically false
  }
}

// In UI - isRunning automatically prevents double-clicks
Command<MyViewModel>(
  command: (vm) => vm.fetchCommand,
  builder: (context, execute, canExecute, isRunning) {
    if (isRunning) return CircularProgressIndicator();
    return ElevatedButton(
      onPressed: execute,
      child: Text('Fetch Data'),
    );
  },
)
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
  parameter: () => todoId,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

### 4. Data Binding with `Bind`

The `Bind` widget handles reactive data binding. With just a few widgets (`Bind` and `Command`), you're covering almost all your UI binding needs.

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

#### Auto-Binding with `Bind.viewModel`

For multiple properties, use `Bind.viewModel` which automatically tracks accessed properties and bind them:

```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  final age = ObservableProperty<int>(30);
}

// Auto-Binding all accessed properties - no manual selectors needed!
Bind.viewModel<UserViewModel>(
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

**When to use `Bind.viewModel`:**
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
  builder: (context, execute, canExecute, isRunning) {
    return ElevatedButton(
      onPressed: canExecute ? execute : null,  // Auto-disabled
      child: isRunning ? Text('Saving...') : Text('Save'),
    );
  },
)
```

#### Parameterized Commands with `Command.param`

When your command needs parameters, use a function that returns the parameter value for reactive evaluation:

```dart
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteTodoCommand,
  parameter: () => todoId,  // Function for reactive evaluation
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

For reactive parameters from controllers, wrap with `ValueListenableBuilder`:

```dart
Bind<TodoViewModel, TextEditingController>(
  selector: (vm) => vm.titleController,
  builder: (context, controller, _) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Command.param<TodoViewModel, String>(
          command: (vm) => vm.addTodoCommand,
          parameter: () => value.text,  // Reactive to text changes
          builder: (context, execute, canExecute, isRunning) {
            return ElevatedButton(
              onPressed: canExecute ? execute : null,
              child: Text('Add Todo'),
            );
          },
        );
      },
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

#### Bridging ViewModels to Overlays with `FairyBridge`

**Problem:** Overlays (dialogs, bottom sheets, menus) create separate widget trees that can't access parent FairyScopes through normal context lookup.

**Solution:** `FairyBridge` widget captures the parent context's FairyScope and makes it available to the overlay's context.

```dart
class TodoListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Todo List')),
      body: TodoListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => FairyBridge(
        context: context, // Parent context with FairyScope
        child: AlertDialog(
          title: Text('Add Todo'),
          content: Bind<TodoListViewModel, TextEditingController>(
            selector: (vm) => vm.titleController,
            builder: (context, controller, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter todo title',
                    ),
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            Bind<TodoListViewModel, TextEditingController>(
              selector: (vm) => vm.titleController,
              builder: (context, controller, _) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return Command.param<TodoListViewModel, String>(
                      command: (vm) => vm.addTodoCommand,
                      parameter: () => value.text,
                      builder: (context, execute, canExecute, isRunning) {
                        return TextButton(
                          onPressed: canExecute ? execute : null,
                          child: Text('Add'),
                        );
                      },
                    );
                  },
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

**What it does:**
- Looks up parent context's FairyScope
- Creates an InheritedWidget that provides the same scope to overlay
- `Bind` and `Command` widgets inside overlay now work seamlessly
- If no FairyScope found in parent, gracefully returns child (falls back to FairyLocator)

**When to use:**
- Dialogs (`showDialog`)
- Bottom sheets (`showModalBottomSheet`, `showBottomSheet`)
- Menus (`showMenu`)
- Any overlay that creates a new route or separate widget tree

**When NOT needed:**
- Regular navigation (`Navigator.push`) - new routes have access to parent context
- Widgets within the same widget tree - normal context lookup works

## Advanced Features

### ComputedProperty - Automatic Derived Values

`ComputedProperty` is a game-changer for managing derived state. It automatically recomputes when dependencies change, eliminating manual synchronization and making your ViewModels dramatically cleaner.

#### Why You'll Love It

**Without ComputedProperty:**
```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  
  String _fullName = 'John Doe';
  String get fullName => _fullName;
  
  late final VoidCallback disposeFirstNameChanges;
  late final VoidCallback disposeLastNameChanges;
  
  UserViewModel() {
    // Manual listener setup - error-prone and verbose
    disposeFirstNameChanges = firstName.propertyChanged(_updateFullName);
    disposeLastNameChanges = lastName.propertyChanged(_updateFullName);
    _updateFullName();
  }
  
  void _updateFullName() {
    _fullName = '${firstName.value} ${lastName.value}';
    onPropertyChanged(); // Easy to forget!
  }
  
  @override
  void dispose() {
    disposeFirstNameChanges();
    disposeLastNameChanges();
    super.dispose();  // Manual cleanup required (and easy to forget!)
  }
}
```

**With ComputedProperty:**
```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  
  // That's it! Auto-updates, auto-caches, auto-disposes 🎉
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
    this, // Required parent for automatic disposal
  );
}
```

#### Real-World Examples

**Shopping Cart with Chained Computations:**
```dart
class CartViewModel extends ObservableObject {
  final items = ObservableProperty<List<Item>>([]);
  final taxRate = ObservableProperty<double>(0.08);
  final discountCode = ObservableProperty<String?>('');
  
  // Base calculation
  late final subtotal = ComputedProperty<double>(
    () => items.value.fold(0.0, (sum, item) => sum + item.price),
    [items],
    this,
  );
  
  // Depends on another computed property!
  late final discount = ComputedProperty<double>(
    () => discountCode.value == 'SAVE20' ? subtotal.value * 0.20 : 0.0,
    [subtotal, discountCode],
    this,
  );
  
  late final afterDiscount = ComputedProperty<double>(
    () => subtotal.value - discount.value,
    [subtotal, discount],
    this,
  );
  
  late final tax = ComputedProperty<double>(
    () => afterDiscount.value * taxRate.value,
    [afterDiscount, taxRate],
    this,
  );
  
  // Final total - automatically updates when ANYTHING changes!
  late final total = ComputedProperty<double>(
    () => afterDiscount.value + tax.value,
    [afterDiscount, tax],
    this,
  );
}
```

**Form Validation (Perfect for canExecute):**
```dart
class LoginViewModel extends ObservableObject {
  final email = ObservableProperty<String>('');
  final password = ObservableProperty<String>('');
  
  late final isEmailValid = ComputedProperty<bool>(
    () => email.value.contains('@') && email.value.length > 5,
    [email],
    this,
  );
  
  late final isPasswordValid = ComputedProperty<bool>(
    () => password.value.length >= 8,
    [password],
    this,
  );
  
  late final canSubmit = ComputedProperty<bool>(
    () => isEmailValid.value && isPasswordValid.value,
    [isEmailValid, isPasswordValid],
    this,
  );
  
  // Use computed property in command validation
  late final loginCommand = AsyncRelayCommand(
    _login,
    canExecute: () => canSubmit.value,
  );
  
  Future<void> _login() async {
    // Login logic
  }
}
```

**Complex Business Logic:**
```dart
class ProfileViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('');
  final lastName = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);
  final memberSince = ObservableProperty<DateTime>(DateTime.now());
  final isPremium = ObservableProperty<bool>(false);
  
  late final displayName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}'.trim(),
    [firstName, lastName],
    this
  );
  
  late final membershipYears = ComputedProperty<int>(
    () => DateTime.now().year - memberSince.value.year,
    [memberSince],
    this
  );
  
  late final badgeLevel = ComputedProperty<String>(
    () {
      if (isPremium.value) return 'Premium';
      if (membershipYears.value >= 5) return 'Veteran';
      if (membershipYears.value >= 1) return 'Member';
      return 'Newbie';
    },
    [isPremium, membershipYears],
    this
  );
  
  late final profileSummary = ComputedProperty<String>(
    () => '$displayName (${age.value}) - ${badgeLevel.value} Member',
    [displayName, age, badgeLevel],
    this
  );
}
```

#### Key Benefits

✅ **Zero Maintenance** - No manual updates, listeners are managed automatically  
✅ **Performance** - Smart caching, only recomputes when dependencies actually change  
✅ **Composable** - Computed properties can depend on other computed properties  
✅ **Type-Safe** - Strongly-typed with compile-time safety  
✅ **No Memory Leaks** - Auto-disposal handles all cleanup  
✅ **Clean Code** - Declarative dependencies eliminate boilerplate  
✅ **Testable** - Pure functions make unit testing trivial

#### How It Works

1. **Setup**: Registers listeners on all dependencies during construction
2. **Cache**: Computes and caches the initial value
3. **React**: When any dependency changes, invalidates cache and recomputes
4. **Notify**: Notifies its own listeners only if the computed value actually changed
5. **Cleanup**: Auto-disposes all listeners when parent ViewModel is disposed

#### Performance Note

ComputedProperty is highly optimized:
- Only recomputes when dependencies **actually notify** (not just on access)
- Benefits from ObservableProperty's built-in equality checking
- Cached values mean no redundant calculations
- Efficient for complex dependency chains

### Deep Equality for Collections

By default, `ObservableProperty` performs **recursive deep equality** for `List`, `Map`, and `Set`, comparing contents instead of references - even for nested collections! This works automatically without any configuration.

```dart
class TodoViewModel extends ObservableObject {
  // Deep equality for collections (enabled by default)
  final tags = ObservableProperty<List<String>>(['flutter', 'dart']);
  
  // Works with nested collections too!
  final matrix = ObservableProperty<List<List<int>>>([[1, 2], [3, 4]]);
  
  void updateTags() {
    // No rebuild - same contents
    tags.value = ['flutter', 'dart'];
    
    // Rebuilds - different contents
    tags.value = ['flutter', 'dart', 'web'];
    
    // Nested collections work automatically!
    matrix.value = [[1, 2], [3, 4]];  // No rebuild (same nested contents)
    matrix.value = [[1, 2], [3, 5]];  // Rebuilds (different nested contents)
  }
}
```

**Handles arbitrary nesting depth:**

```dart
// 3 levels deep: List<Map<String, List<int>>>
final deepData = ObservableProperty([
  {'a': [1, 2], 'b': [3, 4]},
  {'c': [5, 6], 'd': [7, 8]},
]);

// Same data, different objects - no rebuild! 🎉
deepData.value = [
  {'a': [1, 2], 'b': [3, 4]},
  {'c': [5, 6], 'd': [7, 8]},
];

// Changed deep nested value - rebuilds correctly
deepData.value = [
  {'a': [1, 2], 'b': [3, 4]},
  {'c': [5, 6], 'd': [7, 9]},  // Changed 8 to 9
];
```

**Disable deep equality if you need reference equality:**

```dart
final items = ObservableProperty<List<Item>>(
  [],
  deepEquality: false,  // Use reference equality
);

// Now rebuilds on every assignment (different reference)
items.value = [...items.value];
```

**Using the `Equals` utility class directly:**

```dart
import 'package:fairy/fairy.dart';

// Direct comparison utilities (with deep equality)
bool same = Equals.listEquals([1, 2], [1, 2]);  // true
bool nested = Equals.listEquals([[1, 2]], [[1, 2]]);  // true (nested!)
bool maps = Equals.mapEquals({'a': 1}, {'a': 1});  // true
bool sets = Equals.setEquals({1, 2}, {2, 1});  // true (order doesn't matter)

// Deep collection equality for any type
bool complex = Equals.deepCollectionEquals(
  {'users': [{'name': 'Alice'}]},
  {'users': [{'name': 'Alice'}]},
); // true!

// Hash codes for using collections as map keys
int hash = Equals.listHash([[1, 2], [3, 4]]);
```

### Custom Type Equality

**Custom types automatically use their `==` operator** - no special configuration needed:

```dart
class User {
  final String id;
  final String name;
  
  User(this.id, this.name);
  
  // Override == to define custom equality (optional)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// Works automatically - uses User's == operator
final user = ObservableProperty<User>(User('1', 'Alice'));
user.value = User('1', 'Bob');  // No rebuild (same id)
user.value = User('2', 'Alice');  // Rebuilds (different id)
```

**For custom types containing collections (optional optimization):**

Deep equality works automatically for collections at any level. However, if you want to optimize equality checks for frequently-compared custom types, you can optionally override `==`:

```dart
class Project {
  final String name;
  final List<String> tasks;
  
  Project(this.name, this.tasks);
  
  // OPTIONAL: Override == for optimized comparisons
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          name == other.name &&
          Equals.listEquals(tasks, other.tasks);
  
  @override
  int get hashCode => name.hashCode ^ Equals.listHash(tasks);
}

// Without overriding ==, ObservableProperty will use reference equality
// for custom types, which works fine but may trigger more rebuilds
final project = ObservableProperty<Project>(
  Project('Work', ['Task 1'])
);
project.value = Project('Work', ['Task 1']);  // Rebuilds (different reference)

// With overridden ==, it compares by value
// project.value = Project('Work', ['Task 1']);  // No rebuild (same value)
```

**Key Point:** You only need to override `==` for custom types if you want value-based equality instead of reference equality. The collections inside will be compared deeply either way when you do override `==`.

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
  
  VoidCallback? disposePropertyChanges;
  
  MyViewModel() {
    // When canExecute depends on other state
    disposePropertyChanges = selectedItem.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
      editCommand.notifyCanExecuteChanged();
    });
  }
  
  void _delete() { /* ... */ }
  void _edit() { /* ... */ }
  
  @override
  void dispose() {
    disposePropertyChanges?.call();
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
  late VoidCallback disposePropertyChanges;
  late VoidCallback disposeCommandChanges;
  
  @override
  void initState() {
    super.initState();
    final vm = Fairy.of<MyViewModel>(context);
    
    // Store the disposers
    disposePropertyChanges = vm.counter.propertyChanged(() {
      setState(() {});
    });
    
    disposeCommandChanges = vm.saveCommand.canExecuteChanged(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    disposePropertyChanges(); // Clean up listeners
    disposeCommandChanges();
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
  builder: (context, execute, canExecute, isRunning) => 
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

**For multiple properties:** Use `Bind.viewModel` for convenience with excellent selective efficiency:

```dart
// ✅ Best for multiple properties
Bind.viewModel<UserViewModel>(
  builder: (context, vm) {
    return Text('${vm.firstName.value} ${vm.lastName.value}');
    // Both properties automatically bounded!
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

Fairy is thoroughly tested with **401 tests** passing, covering all core functionality including observable properties, commands, auto-disposal, dependency injection, widget binding, deep equality, and overlay scenarios.

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

testWidgets('Bind.viewModel rebuilds on property change', (tester) async {
  final vm = UserViewModel();
  
  await tester.pumpWidget(
    MaterialApp(
      home: FairyScope(
        viewModel: (_) => vm,
        child: Bind.viewModel<UserViewModel>(
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
| Boilerplate | **Low** | Low | Medium | Low | High |
| Learning Curve | **Low** | Low | Medium | Low | Medium |
| Command Pattern | **✅** | ❌ | ❌ | ❌ | ❌ |
| Two-Way Binding | **✅** | ❌ | ❌ | ✅ | ❌ |
| Auto-Disposal | **✅** | ⚠️ | ✅ | ✅ | ⚠️ |

## License

BSD 3-Clause License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
