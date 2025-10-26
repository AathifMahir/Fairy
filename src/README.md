<div align="center">
  <img src="logo.png" alt="Fairy Logo" width="300"/>
</div>

A lightweight MVVM framework for Flutter with strongly-typed reactive data binding, commands, and dependency injection - no code generation required.

**Simplicity over complexity** - Clean APIs, minimal boilerplate, zero dependencies.

## 📖 Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Quick Reference](#quick-reference)
- [Common Patterns](#common-patterns)
- [Core Concepts](#core-concepts)
- [Dependency Injection](#dependency-injection)
- [Best Practices](#best-practices)
- [Performance](#performance)
- [Testing](#testing)

## Features

- 🎓 **Few Widgets to Learn** - `Bind` for data, `Command` for actions
- 🎯 **Type-Safe** - Strongly-typed with compile-time safety
- ✨ **No Code Generation** - Runtime-only, no build_runner
- 🔄 **Auto UI Updates** - Data binding that just works
- ⚡ **Command Pattern** - Actions with `canExecute` validation
- 🏗️ **Dependency Injection** - Global and scoped DI
- 📦 **Lightweight** - Zero external dependencies

## Installation

```yaml
dependencies:
  fairy: ^1.3.5
```

## Quick Start

```dart
// 1. Create ViewModel
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  late final incrementCommand = RelayCommand(() => counter.value++);
}

// 2. Provide ViewModel with FairyScope
void main() => runApp(
  FairyScope(
    viewModel: (_) => CounterViewModel(),
    child: MyApp(),
  ),
);

// 3. Bind UI
Bind<CounterViewModel, int>(
  selector: (vm) => vm.counter,
  builder: (context, value, update) => Text('$value'),
)

Command<CounterViewModel>(
  command: (vm) => vm.incrementCommand,
  builder: (context, execute, canExecute, isRunning) =>
    ElevatedButton(
      onPressed: canExecute ? execute : null,
      child: Text('Increment'),
    ),
)
```

## Quick Reference

### Property Types

| Type | Purpose | Auto-Updates | Example |
|------|---------|--------------|---------|
| `ObservableProperty<T>` | Mutable reactive state | ✅ | `final name = ObservableProperty<String>('');` |
| `ComputedProperty<T>` | Derived/calculated values | ✅ | `late final total = ComputedProperty(() => price.value * qty.value, [price, qty], this);` |

### Command Types

| Type | Parameters | Async | Example |
|------|-----------|-------|---------|
| `RelayCommand` | ❌ | ❌ | `late final save = RelayCommand(_save);` |
| `AsyncRelayCommand` | ❌ | ✅ | `late final fetch = AsyncRelayCommand(_fetch);` |
| `RelayCommandWithParam<T>` | ✅ | ❌ | `late final delete = RelayCommandWithParam<String>(_delete);` |
| `AsyncRelayCommandWithParam<T>` | ✅ | ✅ | `late final upload = AsyncRelayCommandWithParam<File>(_upload);` |

**Async commands** automatically track `isRunning` and prevent concurrent execution.

### Widget Types

| Widget | Purpose | When to Use |
|--------|---------|-------------|
| `Bind<TViewModel, TValue>` | Single property binding | Best performance, one property |
| `Bind.viewModel<TViewModel>` | Multiple properties | Multiple properties, convenience |
| `Command<TViewModel>` | Bind commands | Buttons, actions |
| `Command.param<TViewModel, TParam>` | Parameterized commands | Delete item, update with value |

## Common Patterns

### Form with Validation

```dart
class LoginViewModel extends ObservableObject {
  final email = ObservableProperty<String>('');
  final password = ObservableProperty<String>('');
  
  late final isValid = ComputedProperty<bool>(
    () => email.value.contains('@') && password.value.length >= 8,
    [email, password], this,
  );
  
  late final loginCommand = AsyncRelayCommand(_login, 
    canExecute: () => isValid.value);
  
  Future<void> _login() async { /* ... */ }
}
```

### List Operations

```dart
final todos = ObservableProperty<List<Todo>>([]);

late final addCommand = RelayCommandWithParam<String>(
  (title) => todos.value = [...todos.value, Todo(title)],
);

late final deleteCommand = RelayCommandWithParam<String>(
  (id) => todos.value = todos.value.where((t) => t.id != id).toList(),
);
```

### Loading States

```dart
late final fetchCommand = AsyncRelayCommand(_fetch);

// In UI - isRunning automatically prevents double-taps
Command<MyVM>(
  command: (vm) => vm.fetchCommand,
  builder: (context, execute, canExecute, isRunning) {
    if (isRunning) return CircularProgressIndicator();
    return ElevatedButton(onPressed: execute, child: Text('Fetch'));
  },
)
```

### Dynamic canExecute

```dart
// ViewModel
final selected = ObservableProperty<Item?>(null);

late final deleteCommand = RelayCommand(_delete,
  canExecute: () => selected.value != null);

late final VoidCallback _disposeListener;

MyViewModel() {
  _disposeListener = selected.propertyChanged(() {
    deleteCommand.notifyCanExecuteChanged();
  });
}

@override
void dispose() {
  _disposeListener();
  super.dispose();
}

// UI - Command widget automatically respects canExecute
Command<MyViewModel>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) =>
    ElevatedButton(
      onPressed: canExecute ? execute : null,  // Button disabled when canExecute is false
      child: Text('Delete'),
    ),
)
```

## Core Concepts

### Data Binding

**Single property (two-way):**
```dart
Bind<UserViewModel, String>(
  selector: (vm) => vm.name,  // Returns ObservableProperty - two-way binding
  builder: (context, value, update) => TextField(
    controller: TextEditingController(text: value),
    onChanged: update,  // update() available for two-way binding
  ),
)
```

**Single property (one-way):**
```dart
Bind<UserViewModel, String>(
  selector: (vm) => vm.name.value,  // Returns raw value - one-way binding
  builder: (context, value, update) => Text(value),  // No update needed
)
```

**Multiple properties:**
```dart
Bind.viewModel<UserViewModel>(
  builder: (context, vm) => Text('${vm.firstName.value} ${vm.lastName.value}'),
)
```

**Multiple ViewModels:** Use `Bind.viewModel2/3/4` to bind multiple ViewModels at once:
```dart
Bind.viewModel2<UserViewModel, SettingsViewModel>(
  builder: (context, user, settings) => 
    Text('${user.name.value} - ${settings.theme.value}'),
)
```

### ComputedProperty - Derived Values

```dart
final price = ObservableProperty<double>(10.0);
final qty = ObservableProperty<int>(2);

late final total = ComputedProperty<double>(
  () => price.value * qty.value,
  [price, qty], this,
);
// Automatically recalculates when price or qty changes
```

## Dependency Injection

### FairyScope - Widget-Scoped DI

```dart
// Single ViewModel
FairyScope(
  viewModel: (_) => ProfileViewModel(),
  child: ProfilePage(),
)

// Multiple ViewModels
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (locator) => SettingsViewModel(
      userVM: locator.get<UserViewModel>(),
    ),
  ],
  child: DashboardPage(),
)

// Access in widgets
final vm = Fairy.of<UserViewModel>(context);
```

**Auto-disposal:** `autoDispose: true` (default) automatically disposes ViewModels when scope is removed.

### FairyLocator - Global DI

```dart
// Register services in main()
void main() {
  FairyLocator.instance.registerSingleton<ApiService>(ApiService());
  FairyLocator.instance.registerLazySingleton<DbService>(() => DbService());
  runApp(MyApp());
}

// Use in FairyScope
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    api: locator.get<ApiService>(),
  ),
  child: ProfilePage(),
)
```

### FairyBridge - For Overlays

Use `FairyBridge` to access parent FairyScope in dialogs/overlays:

```dart
showDialog(
  context: context,
  builder: (_) => FairyBridge(
    context: context,
    child: AlertDialog(
      content: Bind<MyViewModel, String>(
        selector: (vm) => vm.data,
        builder: (context, value, _) => Text(value),
      ),
    ),
  ),
);
```

## Advanced Features

### Deep Equality for Collections

`ObservableProperty` automatically performs **deep equality** for `List`, `Map`, and `Set` - even nested collections!

```dart
class TodoViewModel extends ObservableObject {
  final tags = ObservableProperty<List<String>>(['flutter', 'dart']);
  final matrix = ObservableProperty<List<List<int>>>([[1, 2], [3, 4]]);
  
  void updateTags() {
    tags.value = ['flutter', 'dart'];           // No rebuild (same contents)
    tags.value = ['flutter', 'dart', 'web'];    // Rebuilds
    matrix.value = [[1, 2], [3, 4]];            // No rebuild (nested equality!)
  }
}
```

**Disable if needed:** `ObservableProperty<List>([], deepEquality: false)`

### Custom Type Equality

Custom types use their `==` operator. Override it for value-based equality:

```dart
class User {
  final String id;
  final String name;
  
  @override
  bool operator ==(Object other) => other is User && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// For types with collections, use Equals utility:
// Equals.listEquals(list1, list2), Equals.mapEquals(map1, map2)
```

## Best Practices

### Auto-Disposal

Properties and commands are auto-disposed with parent ViewModels. **Exception:** Nested ViewModels require manual disposal:

```dart
class ParentViewModel extends ObservableObject {
  final data = ObservableProperty<String>('');
  late final childVM = ChildViewModel();  // ⚠️ Manual disposal required
  
  @override
  void dispose() {
    childVM.dispose();
    super.dispose();
  }
}
```

**Managing Multiple Disposables:** Use `DisposableBag` for cleaner disposal of multiple resources:

```dart
class MyViewModel extends ObservableObject {
  final _disposables = DisposableBag();
  
  MyViewModel() {
    _disposables.add(property.propertyChanged(() => /* ... */));
    _disposables.add(command.canExecuteChanged(() => /* ... */));
    _disposables.add(_subscription.cancel);  // Any VoidCallback
  }
  
  @override
  void dispose() {
    _disposables.dispose();  // Disposes all at once
    super.dispose();
  }
}
```

### Refresh Commands on Changes

When `canExecute` depends on properties, notify the command:

```dart
class MyViewModel extends ObservableObject {
  final selectedItem = ObservableProperty<Item?>(null);
  late final deleteCommand = RelayCommand(_delete, canExecute: () => selectedItem.value != null);
  
  VoidCallback? disposeChanges;
  
  MyViewModel() {
    disposeChanges = selectedItem.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }
  
  void _delete() { /* ... */ }
  
  @override
  void dispose() {
    disposeChanges?.call();
    super.dispose();
  }
}
```

### Capture Disposers ⚠️

Manual listeners (via `propertyChanged()`/`canExecuteChanged()`) **must** be disposed to avoid memory leaks:

```dart
// ❌ MEMORY LEAK
viewModel.propertyChanged(() { print('changed'); });

// ✅ CORRECT
late VoidCallback dispose;
dispose = viewModel.propertyChanged(() { print('changed'); });
// Later: dispose();

// ✅ BEST: Use Bind/Command widgets (auto-managed)
Bind<MyViewModel, int>(
  selector: (vm) => vm.counter,
  builder: (context, value, _) => Text('$value'),
)
```

Auto-disposal only handles properties/commands, not manually registered listeners. Always capture disposers or use `Bind`/`Command` widgets.

### Use Scoped DI

```dart
// ✅ Scoped ViewModels auto-dispose
FairyScope(
  viewModel: (_) => UserProfileViewModel(userId: widget.userId),
  child: UserProfilePage(),
)
```

### Choose Right Binding

- **Single property (two-way):** `Bind<VM, T>` with `selector: (vm) => vm.prop` (returns ObservableProperty)
- **Single property (one-way):** `Bind<VM, T>` with `selector: (vm) => vm.prop.value` (returns raw value)
- **Multiple properties:** `Bind.viewModel<VM>` for auto-tracking
- **Avoid:** Creating new instances in selectors (causes infinite rebuilds)

## Performance

Fairy is designed for performance. Benchmark results comparing with popular state management solutions (averaged over 5 runs with engine warm-up):

| Category | Fairy | Provider | Riverpod |
|----------|-------|----------|----------|
| Widget Performance (1000 interactions) | 101.8% | 106.2% | **100%** 🥇 |
| Memory Management (50 cycles) | **100%** 🥇 | 106.7% | 100.5% |
| Selective Rebuild (explicit Bind) | **100%** 🥇 | 134.0% | 122.6% |
| Rebuild Performance (auto-binding) | **100%** 🥇 | 103.9% | 100.9% |

### Key Achievements
- **🥇 Best Memory Management** - 0.5% faster than Riverpod, 6.7% faster than Provider
- **🥇 Fastest Selective Rebuilds** - 22.6-34% faster
- **🥇 Fastest Auto-binding** - 0.9-3.9% faster with 100% rebuild efficiency
- **Unique**: Only framework achieving 100% selective efficiency vs 33% for Provider/Riverpod

*Lower is better. Percentages relative to the fastest framework in each category.*

## Example

See the [example](../example) directory for a complete counter app demonstrating:
- MVVM architecture
- Reactive properties
- Command pattern with canExecute
- Data and command binding
- Scoped dependency injection

## Testing

**543 tests passing** - covering observable properties, commands, auto-disposal, dependency injection, widget binding, deep equality, and overlays.

```dart
test('increment updates counter', () {
  final vm = CounterViewModel();
  vm.incrementCommand.execute();
  expect(vm.counter.value, 1);
  vm.dispose();
});

testWidgets('counter increments on tap', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: FairyScope(
      viewModel: (_) => CounterViewModel(),
      child: CounterPage(),
    ),
  ));
  
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  expect(find.text('1'), findsOneWidget);
});
```

## Architecture Guidelines

### ViewModel
✅ **DO**: Business logic, state (ObservableProperty), commands, derived values (ComputedProperty)  
❌ **DON'T**: Reference BuildContext/widgets, navigation, UI logic, styling

### View (Widgets)
✅ **DO**: Use `Bind`/`Command` widgets, handle navigation, declarative composition  
❌ **DON'T**: Business logic, data validation, direct state modification

### Binding Patterns
✅ **DO**: 
- One-way (read-only): `selector: (vm) => vm.property.value`
- Two-way (editable): `selector: (vm) => vm.property` (returns ObservableProperty)
- Tuples (one-way): `selector: (vm) => (vm.a.value, vm.b.value)` ← All `.value`!

❌ **DON'T**: 
- Mix in tuples: `(vm.a.value, vm.b)` ← TypeError!
- Create new instances in selectors ← Infinite rebuilds!

### Commands
✅ **DO**: Call `notifyCanExecuteChanged()` when conditions change, use `AsyncRelayCommand` for async  
❌ **DON'T**: Long operations in sync commands, forget to update `canExecute`

### Dependency Injection
✅ **DO**: `FairyScope` for pages/features, `FairyLocator` for app-wide services, `FairyBridge` for overlays  
❌ **DON'T**: Register ViewModels globally, manually dispose FairyScope ViewModels

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
