<div align="center">
  <img src="src/logo.png" alt="Fairy Logo" width="300"/>


  [![pub package](https://img.shields.io/pub/v/fairy.svg)](https://pub.dev/packages/fairy)
  [![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white)](https://flutter.dev)

</div>

A lightweight MVVM framework for Flutter that provides strongly-typed, reactive data binding without code generation. Fairy combines reactive properties, command patterns, and dependency injection with minimal boilerplate.

## 🎯 Design Philosophy

**Simplicity Over Complexity** - Fairy is built around the principle that state management should be simple and intuitive. With just a **few widgets and types**, you have everything you need for most use cases. This simplicity-first approach is reflected throughout the entire library design, making it easy to learn, easy to use, and easy to maintain.

## ✨ Why Fairy?

- **Few Widgets to Learn** - `Bind` for data, `Command` for actions - covers almost everything
- **No Build Runner** - Pure runtime implementation, zero build_runner headaches
- **Type-Safe** - Strongly-typed reactive properties with compile-time safety
- **Auto UI Updates** - Data binding that just works
- **Command Pattern** - Built-in action encapsulation with `canExecute` validation
- **DI Built-in** - Both scoped and global dependency injection
- **Minimal Code** - Clean, intuitive API that stays out of your way
- **Lightweight** - Small footprint, zero external dependencies

## 📦 Installation

```yaml
dependencies:
  fairy: ^1.2.0
```

## 🚀 Quick Start

```dart
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

// 1️⃣ Create a ViewModel
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  final multiplier = ObservableProperty<int>(2);
  late final incrementCommand = RelayCommand(() => counter.value++);
  late final addCommand = RelayCommandWithParam<int>((amount) => counter.value += amount);
}

// 2️⃣ Provide it with FairyScope
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

// 3️⃣ Bind to UI
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Explicit binding (recommended for single properties)
            Bind<CounterViewModel, int>(
              selector: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
            // Auto-Binding (convenient for multiple properties)
            Bind.viewModel<CounterViewModel>(
              builder: (context, vm) => Text('Count: ${vm.counter.value} × ${vm.multiplier.value}'),
            ),
            // Regular command
            Command<CounterViewModel>(
              command: (vm) => vm.incrementCommand,
              builder: (context, execute, canExecute, isRunning) {
                return ElevatedButton(
                  onPressed: execute,
                  child: Text('Increment'),
                );
              },
            ),
            // Parameterized command
            Command.param<CounterViewModel, int>(
              command: (vm) => vm.addCommand,
              parameter: () => 5,
              builder: (context, execute, canExecute, isRunning) {
                return ElevatedButton(
                  onPressed: execute,
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

That's it! No code generation, no complex setup. Just clean, reactive MVVM.

## 🎯 Core Features

### Reactive Properties

```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  final age = ObservableProperty<int>(30);
  
  // ComputedProperty automatically updates when dependencies change!
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
  );
  
  late final displayInfo = ComputedProperty<String>(
    () => '$fullName, age ${age.value}',
    [fullName, age], // Can depend on other computed properties!
  );
}
```

### Commands with Validation

```dart
class TodoViewModel extends ObservableObject {
  final selectedItem = ObservableProperty<Todo?>(null);
  
  late final deleteCommand = RelayCommand(
    _delete,
    canExecute: () => selectedItem.value != null,
  );
  
  late final deleteItemCommand = RelayCommandWithParam<String>(
    (id) => _deleteById(id),
    canExecute: (id) => selectedItem.value?.id == id,
  );
  
  void _delete() {
    // Delete logic
  }
  
  void _deleteById(String id) {
    // Delete by ID
  }
}

// In UI
Command<TodoViewModel>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)

// Parameterized command
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteItemCommand,
  parameter: () => todoId,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

### Async Commands

Async commands automatically track execution state with `isRunning`, preventing concurrent execution and enabling easy loading indicators:

```dart
class DataViewModel extends ObservableObject {
  late final fetchCommand = AsyncRelayCommand(_fetchData);
  
  Future<void> _fetchData() async {
    // fetchCommand.isRunning automatically managed
    await api.getData();
  }
}

// In UI
Command<DataViewModel>(
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

### Data Binding

```dart
// Explicit binding - best for single properties
Bind<UserViewModel, String>(
  selector: (vm) => vm.name,
  builder: (context, value, update) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: update,  // Two-way binding
    );
  },
)

// Auto-Binding - best for multiple properties
Bind.viewModel<UserViewModel>(
  builder: (context, vm) {
    return Column(
      children: [
        Text('${vm.firstName.value} ${vm.lastName.value}'),
        Text('Age: ${vm.age.value}'),
        // All accessed properties automatically tracked!
      ],
    );
  },
)
```

### Deep Equality for Collections

Built-in recursive deep equality for collections without external dependencies:

```dart
class TodoViewModel extends ObservableObject {
  // Deep equality enabled by default
  final tags = ObservableProperty<List<String>>(['flutter', 'dart']);
  
  void updateTags() {
    tags.value = ['flutter', 'dart'];  // No rebuild - same contents!
    tags.value = ['flutter', 'web'];   // Rebuilds - different contents
  }
}

// Works with nested collections automatically
final deepData = ObservableProperty([
  {'a': [1, 2], 'b': [3, 4]},
  {'c': [5, 6], 'd': [7, 8]},
]);
```

### Dependency Injection

```dart
// Scoped (auto-disposed) - use anywhere in your widget tree!
FairyScope(
  viewModel: (_) => ProfileViewModel(userId: widget.userId),
  child: ProfilePage(),
)

// Multiple ViewModels in one scope
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (_) => SettingsViewModel(),
  ],
  child: DashboardPage(),
)

// Global singleton
FairyLocator.instance.registerSingleton<ApiService>(ApiService());

// Access from FairyScope with dependency injection
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    api: locator.get<ApiService>(),
  ),
  child: ProfilePage(),
)

// Bridge ViewModels to overlays (dialogs, bottom sheets)
void _showDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => FairyBridge(
      context: context, // Makes parent FairyScope available
      child: AlertDialog(
        // Command and Bind widgets now work!
        actions: [
          Command<MyViewModel>(
            command: (vm) => vm.saveCommand,
            builder: (ctx, execute, canExecute, isRunning) =>
              TextButton(onPressed: execute, child: Text('Save')),
          ),
        ],
      ),
    ),
  );
}
```

## 📊 Performance

Fairy is designed for performance. Here are benchmark results comparing with popular state management solutions (averaged over 5 runs with engine warm-up):

| Category | Fairy | Provider | Riverpod |
|----------|-------|----------|----------|
| Widget Performance (1000 interactions) | 101.8% | 106.2% | **100%** 🥇 |
| Memory Management (50 cycles) | **100%** 🥇 | 106.7% | 100.5% |
| Selective Rebuild (explicit Bind) | **100%** 🥇 | 134.0% | 122.6% |
| Rebuild Performance (auto-binding) | **100%** 🥇 | 103.9% | 100.9% |

### 🏆 Fairy Achievements
- **🥇 Best Memory Management** - 0.5% faster than Riverpod, 6.7% faster than Provider
- **🥇 Fastest Selective Rebuilds** - 22.6-34% faster
- **🥇 Fastest Auto-binding** - 0.9-3.9% faster with 100% rebuild efficiency
- **Competitive Widget Performance** - Within 1.8% of fastest
- **Unique**: Only framework achieving 100% selective efficiency vs 33% for Provider/Riverpod

*Lower is better. Percentages relative to the fastest framework in each category.*

**Key Insights:**
- ⚡ **3 Gold Medals** in memory, selective rebuilds, and auto-binding
- 🎯 **100% Rebuild Efficiency** with `Bind.viewModel` - zero unnecessary rebuilds
- 📊 **Reliable Results** - Averaged over 5 runs with engine warm-up

## 📚 Documentation

- [**Getting Started**](./src/README.md) - Complete guide with examples
- [**API Reference**](https://pub.dev/documentation/fairy/latest/) - Full API documentation
- [**Example App**](./example) - Complete counter app demo
- [**Benchmarks**](./benchmark) - Performance comparison


## 🧪 Testing

Fairy is thoroughly tested with **493 tests** passing, covering:
- ✅ Observable properties and computed properties
- ✅ All command types (sync, async, parameterized)
- ✅ Auto-disposal and memory management
- ✅ Dependency injection (scoped and global)
- ✅ Widget binding and lifecycle
- ✅ Complex scenarios (nested scopes, inter-VM dependencies)
- ✅ Deep equality for collections
- ✅ FairyBridge overlay scenarios

## 🎨 Architecture Guidelines

### ViewModel ✅ DO
- Contain business logic
- Manage state with ObservableProperty
- Expose commands for actions
- Coordinate with services

### ViewModel ❌ DON'T
- Reference BuildContext or widgets
- Perform navigation
- Contain UI logic or styling

### View ✅ DO
- Declarative widget composition
- Bind to ViewModel properties/commands
- Handle navigation

### View ❌ DON'T
- Contain business logic
- Directly modify app state
- Perform data validation

## 🆚 Comparison

| Feature | Fairy | Provider | Riverpod | GetX | BLoC |
|---------|-------|----------|----------|------|------|
| Code Generation | ❌ | ❌ | ✅ | ❌ | ❌ |
| Type Safety | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Boilerplate | **Low** | Low | Medium | Low | High |
| Learning Curve | **Low** | Low | Medium | Low | Medium |
| Command Pattern | **✅** | ❌ | ❌ | ❌ | ❌ |
| Two-Way Binding | **✅** | ❌ | ❌ | ✅ | ❌ |
| Auto-Disposal | **✅** | ⚠️ | ✅ | ✅ | ⚠️ |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](./src/LICENSE) file for details.

## 🌟 Support

If you find Fairy helpful, please consider:
- ⭐ Starring the repository
- 📢 Sharing it with your friends
- 🐛 Reporting issues
- 💡 Suggesting new features

## 📧 Contact

- **Issues**: [GitHub Issues](https://github.com/AathifMahir/Fairy/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AathifMahir/Fairy/discussions)

---
