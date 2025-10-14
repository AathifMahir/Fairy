## 1.0.0-rc.4

### 🔄 Breaking Changes

#### Command.param Renamed to Command.withParam
- **BREAKING**: `Command.param` factory constructor renamed to `Command.withParam`
  - **Reason**: More explicit and easier for new users to understand, aligns better with Flutter API design conventions
  - **Migration**: Replace all `Command.param` with `Command.withParam`
  
```dart
// Before
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteTodoCommand,
  parameter: () => todoId,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: const Icon(Icons.delete),
    );
  },
)

// After
Command.withParam<TodoViewModel, String>(
  command: (vm) => vm.deleteTodoCommand,
  parameter: () => todoId,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: const Icon(Icons.delete),
    );
  },
)
```

### 📚 Documentation

- Updated all documentation to use `Command.withParam` instead of `Command.param`
- Updated README examples with new API name
- Updated example app to demonstrate `Command.withParam` usage

## 1.0.0-rc.3

### ✨ New Features

#### Async Command Execution State Tracking
- **`isRunning` property** added to async commands for automatic execution state tracking
  - **`AsyncRelayCommand.isRunning`**: Tracks execution state (true while running, false otherwise)
  - **`AsyncRelayCommandWithParam<T>.isRunning`**: Same behavior for parameterized async commands
  - **Automatic concurrent execution prevention**: `canExecute` returns `false` while `isRunning` is `true`
  - Eliminates need for manual loading state management
  - Prevents double-click bugs automatically
  - Enables easy loading indicators in UI

#### Command Widget API Enhancement
- **4th parameter `isRunning`** added to all Command builder signatures for consistency
  - **`Command<TViewModel>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - **`Command.param<TViewModel, TParam>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - Async commands return actual `isRunning` state from the command
  - Consistent API across all command types

```dart
// Async command with loading indicator
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

// Sync command (isRunning always false)
Command<TodoViewModel>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

#### Overlay ViewModel Bridging
- **`Fairy.bridge()`**: New utility to bridge ViewModels to overlay widget trees
  - Solves the problem of dialogs, bottom sheets, and menus creating separate widget trees
  - Captures parent context's FairyScope and makes it available to overlay
  - Enables `Bind` and `Command` widgets to work seamlessly in overlays
  - Gracefully falls back to FairyLocator if no FairyScope found

```dart
void _showDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => Fairy.bridge(
      context: context, // Makes parent FairyScope available
      child: AlertDialog(
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

### 🔄 Breaking Changes

#### Command.param Parameter Type Change
- **BREAKING**: `Command.param` parameter changed from static `TParam` to function `TParam Function()`
  - **Reason**: Enables reactive parameter evaluation on rebuild
  - **Before**: `parameter: todoId,`
  - **After**: `parameter: () => todoId,`
  - For reactive controller values, wrap with `ValueListenableBuilder`:

```dart
// Before (static parameter - doesn't react to changes)
Command.param<TodoViewModel, String>(
  parameter: controller.text, // Static value
  builder: (context, execute, canExecute) { ... },
)

// After (reactive parameter)
ValueListenableBuilder<TextEditingValue>(
  valueListenable: controller,
  builder: (context, value, _) {
    return Command.param<TodoViewModel, String>(
      parameter: () => value.text, // Reactive to text changes
      builder: (context, execute, canExecute, isRunning) { ... },
    );
  },
)
```

#### Command Builder Signature Update
- **BREAKING**: All Command builder signatures now include 4th `isRunning` parameter
  - **Before**: `builder: (context, execute, canExecute) { ... }`
  - **After**: `builder: (context, execute, canExecute, isRunning) { ... }`
  - Applies to both `Command<TViewModel>` and `Command.param<TViewModel, TParam>`
  - `isRunning` is always present but only meaningful for async commands (false for sync)

### 🧪 Testing

- **401 tests** passing
- Updated 5 tests for new concurrent execution prevention behavior
- Added tests for `isRunning` state tracking
- Added tests for Command widget `isRunning` parameter

#### 📚 Documentation

- Added comprehensive examples for `isRunning` usage
- Added `Fairy.bridge()` documentation and examples
- Updated all Command widget examples with 4th parameter
- Added ValueListenableBuilder pattern for reactive parameters
- Updated llms.txt with new API surface

---

## 1.0.0-rc.2

### ✨ New Features

#### Recursive Deep Equality for Collections
- **Built-in recursive deep equality** for all collection types without external dependencies
  - Automatically handles arbitrary nesting depth: `List<Map<String, List<int>>>`
  - Works with `List`, `Map`, `Set`, and `Iterable` at any level
  - Custom types use their `==` operator when nested in collections
  - **Zero configuration needed** - deep equality enabled by default

#### Equals Utility Class
- **`Equals.deepCollectionEquals(Object? e1, Object? e2)`**: Recursive equality for any collection type
- **`Equals.deepCollectionHash(Object? o)`**: Recursive hash code generation
- **Collection-specific methods**: `listEquals`, `mapEquals`, `setEquals` with deep comparison
- **Hash methods**: `listHash`, `mapHash`, `setHash` for consistent hash codes
- **`Equals.deepEquals<T>()`**: Factory method for `ObservableProperty` equality parameter

### 🔧 API Enhancements

#### ObservableProperty Deep Equality
- **`deepEquality: bool`** parameter (default: `true`) for automatic collection comparison
  - Primitive types: `ObservableProperty<int>(0)` - uses `==`
  - Collections: `ObservableProperty<List<int>>([1, 2, 3])` - uses deep equality
  - Custom types: Override `==` operator is **optional** (only needed for value-based equality)

### 📚 Developer Experience

#### Optional Equality Override
- **Simplified workflow**: No need to override `==` for custom types with collections
  - Collections are compared deeply automatically
  - Override `==` only if you want value-based equality instead of reference equality
  - Use `Equals` utilities in custom `==` implementations when overriding

```dart
// Works automatically without custom ==
final todos = ObservableProperty<List<String>>(['Task 1', 'Task 2']);
todos.value = ['Task 1', 'Task 2'];  // ✅ No rebuild - deep equality

// Custom type - override == is optional
class Project {
  final String name;
  final List<String> tasks;
  
  // OPTIONAL: Override for value-based equality
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Project &&
      name == other.name &&
      Equals.listEquals(tasks, other.tasks);
}
```

### 🧪 Testing

- **387 tests** passing (up from 344)
- Added **43 comprehensive deep equality tests**:
  - Simple collections (List, Map, Set)
  - Nested structures with 2-3 levels of nesting
  - Mixed nested structures: `List<Map<String, List<int>>>`
  - Sets with nested lists
  - Custom types with and without equality overrides
  - Nested custom types containing collections
  - Performance and memory tests

### 🚀 Performance

- Deep equality optimized with fast-path `identical()` checks
- Recursive comparison with efficient callback pattern
- No performance impact on primitive types
- Benchmarks show excellent overall performance maintained

---

## 1.0.0-rc.1

### 🎉 Major Release Candidate

This release represents a major milestone with significant API improvements, enhanced performance, and comprehensive testing.

### ✨ New Features

#### UI Widgets API Enhancement
- **`Bind.observer<TViewModel>`**: New factory constructor for automatic property tracking
  - Eliminates need for manual selectors when displaying multiple properties
  - Automatically tracks all accessed properties and rebuilds only when they change
  - Achieves great selective rebuild efficiency over other state management solutions
  - 4-10% faster than competitors while maintaining perfect selectivity
- **`Command.param<TViewModel, TParam>`**: New factory constructor for parameterized commands
  - Provides consistent API alongside `Command<TViewModel>`
  - Simplifies parameterized command binding in UI
  - Completes the "2 widgets" framework positioning

### 🔄 Breaking Changes

#### Removed Extensions
- **BREAKING**: Removed `ObservableObjectExtensions` for creating properties/commands
  - **Before (Properties)**: `final counter = observableProperty<int>(0);`
  - **After (Properties)**: `final counter = ObservableProperty<int>(0);`
  - **Before (Commands)**: `late final saveCommand = relayCommand(_save);`
  - **After (Commands)**: `late final saveCommand = RelayCommand(_save);`
  - **Reason**: Direct type usage is clearer, more discoverable, and follows Dart conventions
  - **Migration**: Replace all `observableProperty<T>()` with `ObservableProperty<T>()`
  - **Migration**: Replace all `computedProperty<T>()` with `ComputedProperty<T>()`
  - **Migration**: Replace all command helpers (`relayCommand`, `asyncRelayCommand`, etc.) with direct constructors (`RelayCommand`, `AsyncRelayCommand`, etc.)

#### Command Constructor Changes
- **BREAKING**: Removed `parent` parameter from all command constructors
  - **Before**: `RelayCommand(execute, parent: this, canExecute: ...)`
  - **After**: `RelayCommand(execute, canExecute: ...)`
  - **Reason**: Auto-disposal makes parent tracking unnecessary
  - **Migration**: Remove `parent: this` from all command instantiations

### 🚀 Performance Improvements

Comprehensive benchmarks show significant performance achievements:
- **🥇 Memory Management**: Highly optimized cleanup and disposal system
- **🥇 Selective Rebuilds**: Exceptional performance with explicit `Bind` selectors
- **🥇 Auto-tracking Performance**: `Bind.observer` delivers superior speed while maintaining perfect selectivity
- **Unique Achievement**: 100% rebuild efficiency with `Bind.observer` - only rebuilds when accessed properties change

### 📚 Documentation Improvements

- Updated all examples to use direct type constructors
- Added comprehensive `Bind.observer` usage examples
- Added `Command.param` examples throughout documentation
- "2 widgets" framework (Learn just `Bind` and `Command`)
- Enhanced best practices section with memory leak warnings
- Added benchmark results to main README

### 🧪 Testing

- **344 tests** passing (up from 299)
- Added comprehensive tests for new `Bind.observer` functionality
- Added tests for `Command.param` factory constructor
- All existing functionality validated with updated API

### 📦 What's Next

The 1.0.0 stable release is planned after community feedback on this RC. Please report any issues or suggestions!

---

## 0.5.0+2

- Improved documentation and fixed minor typos.

## 0.5.0+1

- Improved documentation and fixed minor typos.

## 0.5.0

Initial release of Fairy - A lightweight MVVM framework for Flutter.

### Features

#### Core Primitives
- **ObservableObject**: Base ViewModel class with clean MVVM API
  - `onPropertyChanged()` for manual notifications
  - `propertyChanged(listener)` method returning disposer function
  - `setProperty<T>()` helper for batch updates with change detection
  - **Auto-disposal**: Properties created during construction are automatically disposed
- **ObservableProperty<T>**: Strongly-typed reactive properties
  - Automatic change notifications with custom equality support
  - `propertyChanged(listener)` for subscribing to property changes (returns disposer)
  - Auto-disposal when parent ObservableObject is disposed
- **ComputedProperty<T>**: Derived properties with automatic dependency tracking
  - Read-only computed values based on other properties
  - Automatic updates when dependencies change
  - Auto-disposal when parent ObservableObject is disposed

#### Commands
- **RelayCommand**: Synchronous commands with optional `canExecute` validation
- **AsyncRelayCommand**: Asynchronous commands with automatic `isRunning` state
- **RelayCommandWithParam<T>**: Parameterized commands for actions requiring input
- **AsyncRelayCommandWithParam<T>**: Async parameterized commands
- All commands use named parameters: `execute:`, `canExecute:`, `parent:`
- `notifyCanExecuteChanged()` method to re-evaluate `canExecute` conditions
- `canExecuteChanged(listener)` method for subscribing to `canExecute` changes (returns disposer function)

#### Dependency Injection
- **FairyLocator**: Global singleton registry for app-wide services
  - `registerSingleton<T>()` for singleton registration
  - `registerFactory<T>()` for factory registration
  - `get<T>()` for service resolution
  - `unregister<T>()` for cleanup
- **FairyScope**: Widget-scoped DI with automatic disposal
  - Scoped ViewModels auto-disposed when widget tree is removed
  - Supports both `create` and `instance` parameters
- **Fairy (ViewModelLocator)**: Unified resolution checking scope → global → exception
  - `Fairy.of<T>(context)`: Idiomatic Flutter API for resolving ViewModels (similar to `Provider.of`, `Theme.of`)
  - `Fairy.maybeOf<T>(context)`: Optional resolution returning `null` if not found

#### UI Binding
- **Bind<TViewModel, TValue>**: Automatic one-way/two-way binding detection
  - Returns `ObservableProperty<T>` → two-way binding with `update` callback
  - Returns raw `T` → one-way binding (read-only)
  - Type-safe selector/builder contracts
- **Command<TViewModel>**: Command binding with automatic `canExecute` reactivity
- **CommandWithParam<TViewModel, TParam>**: Parameterized command binding

#### Auto-Disposal System
- **Parent Parameter**: Properties, commands, and computed properties accept optional `parent` parameter
  - Pass `parent: this` in constructor to enable automatic disposal
  - Children are registered with parent and disposed automatically
  - Debug warnings shown when parent is not provided
  - Nested ObservableObject instances must be disposed manually

### Memory Management

- **Auto-disposal**: ObservableProperty, ComputedProperty, and Commands automatically disposed when `parent` parameter is provided
- **Nested ViewModels Exception**: Nested ObservableObject instances require manual disposal
- **Manual Listeners**: Always capture disposer from `propertyChanged()` and `canExecuteChanged()` calls to avoid memory leaks
- Use `Bind` and `Command` widgets for UI (automatic lifecycle management)

### Best Practices

- ⚠️ **Memory Leak Prevention**: Always capture disposer from manual `propertyChanged()` and `canExecuteChanged()` calls
- Pass `parent: this` to properties, commands, and computed properties for auto-disposal
- Nested ViewModels require explicit manual disposal
- Call `command.notifyCanExecuteChanged()` when `canExecute` dependencies change
- Use `command.canExecuteChanged(listener)` to listen to `canExecute` state changes
- Selectors must return stable property references
- Use `FairyScope` for page-level ViewModels (handles disposal automatically)
- Use named parameters for commands: `execute:`, `canExecute:`, `parent:`

### Documentation

- Comprehensive README with quick start guide
- Auto-disposal explanation and migration patterns
- Complete API reference with examples
- Example app demonstrating MVVM patterns

### Testing

- Comprehensive unit and widget tests with 100% passing rate
- Tests cover all core primitives, DI patterns, UI bindings, and auto-disposal
- Test structure mirrors library organization
