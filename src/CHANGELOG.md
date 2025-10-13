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
