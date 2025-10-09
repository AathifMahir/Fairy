# 🧚 Fairy

[![pub package](https://img.shields.io/pub/v/fairy.svg)](https://pub.dev/packages/fairy)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white)](https://flutter.dev)

A lightweight MVVM framework for Flutter that provides strongly-typed, reactive data binding without code generation. Fairy combines reactive properties, command patterns, and dependency injection with minimal boilerplate.

## ✨ Why Fairy?

- **🚀 No Build Runner** - Pure runtime implementation, zero build_runner headaches
- **🎯 Type-Safe** - Strongly-typed reactive properties with compile-time safety
- **🔄 Auto UI Updates** - Data binding that just works
- **⚡ Command Pattern** - Built-in action encapsulation with `canExecute` validation
- **🏗️ DI Built-in** - Both scoped and global dependency injection
- **🧩 Minimal Code** - Clean, intuitive API that stays out of your way
- **📦 Lightweight** - Small footprint, zero external dependencies

## 📦 Installation

```yaml
dependencies:
  fairy: ^0.5.0
```

## 🚀 Quick Start

```dart
import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';

// 1️⃣ Create a ViewModel
class CounterViewModel extends ObservableObject {
  final counter = observableProperty<int>(0);
  late final increment = relayCommand(() => counter.value++);
}

// 2️⃣ Provide it with FairyScope (can be used anywhere!)
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

// Or at app root, even above MaterialApp:
void main() {
  runApp(
    FairyScope(
      viewModel: (_) => AppViewModel(),
      child: MyApp(),
    ),
  );
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
            Bind<CounterViewModel, int>(
              selector: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
            Command<CounterViewModel>(
              command: (vm) => vm.increment,
              builder: (context, execute, canExecute) {
                return ElevatedButton(
                  onPressed: execute,
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

That's it! No code generation, no complex setup. Just clean, reactive MVVM.

## 🎯 Core Features

### Reactive Properties

```dart
class UserViewModel extends ObservableObject {
  final name = observableProperty<String>('');
  final age = observableProperty<int>(0);
  
  late final fullInfo = computedProperty<String>(
    () => '${name.value}, age ${age.value}',
    [name, age],
  );
}
```

### Commands with Validation

```dart
class TodoViewModel extends ObservableObject {
  final selectedItem = observableProperty<Todo?>(null);
  
  late final deleteCommand = relayCommand(
    _delete,
    canExecute: () => selectedItem.value != null,
  );
  
  void _delete() {
    // Delete logic
  }
}
```

### Async Commands

```dart
class DataViewModel extends ObservableObject {
  late final fetchCommand = asyncRelayCommand(_fetchData);
  
  Future<void> _fetchData() async {
    // fetchCommand.isRunning automatically managed
    await api.getData();
  }
}
```

### Two-Way Binding

```dart
Bind<UserViewModel, String>(
  selector: (vm) => vm.name,
  builder: (context, value, update) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: update,  // Auto two-way binding
    );
  },
)
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
```

## 📊 Performance

Fairy is designed for performance. Here are benchmark results comparing with popular state management solutions:

| Category | Fairy | Provider | Riverpod |
|----------|-------|----------|----------|
| Widget Performance | **105.9%** | 105.9% | 100% ⚡ |
| Build Performance | 122.4% | **100%** ⚡ | 100.4% |
| Memory Management | **100%** ⚡ | 112.9% | 108.6% |
| Selective Rebuild | **100%** ⚡ | 147.6% | 141.8% |

✨ **Fairy wins in Memory Management and Selective Rebuilds!**

*Lower is better. Percentages relative to the fastest framework.*

## 📚 Documentation

- [**Getting Started**](./src/README.md) - Complete guide with examples
- [**API Reference**](https://pub.dev/documentation/fairy/latest/) - Full API documentation
- [**Example App**](./example) - Complete counter app demo
- [**Benchmarks**](./benchmark) - Performance comparison


## 🧪 Testing

Fairy is thoroughly tested with **299 unit tests** covering:
- ✅ Observable properties and computed properties
- ✅ All command types (sync, async, parameterized)
- ✅ Auto-disposal and memory management
- ✅ Dependency injection (scoped and global)
- ✅ Widget binding and lifecycle
- ✅ Complex scenarios (nested scopes, inter-VM dependencies)

Run tests:
```bash
cd src
flutter test
```

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
