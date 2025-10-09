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
