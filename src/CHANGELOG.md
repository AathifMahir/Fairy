## 0.5.0

Initial release of Fairy - A lightweight MVVM framework for Flutter.

### Features

#### Core Primitives
- **ObservableObject**: Base ViewModel class with clean MVVM API
  - `onPropertyChanged()` for manual notifications
  - `listen()` method returning disposer function
  - `setProperty<T>()` helper for batch updates with change detection
- **ObservableProperty<T>**: Strongly-typed reactive properties
  - Automatic change notifications with custom equality support
  - `listen()` for subscribing to property changes
  - Built-in disposal management
- **ComputedProperty<T>**: Derived properties with automatic dependency tracking
  - Read-only computed values based on other properties
  - Automatic updates when dependencies change

#### Commands
- **RelayCommand**: Synchronous commands with optional `canExecute` validation
- **AsyncRelayCommand**: Asynchronous commands with automatic `isRunning` state
- **RelayCommandWithParam<T>**: Parameterized commands for actions requiring input
- **AsyncRelayCommandWithParam<T>**: Async parameterized commands
- `refresh()` method to re-evaluate `canExecute` conditions

#### Dependency Injection
- **FairyLocator**: Global singleton registry for app-wide services
  - `registerSingleton<T>()` for singleton registration
  - `registerFactory<T>()` for factory registration
  - `get<T>()` for service resolution
  - `unregister<T>()` for cleanup
- **FairyScope**: Widget-scoped DI with automatic disposal
  - Scoped ViewModels auto-disposed when widget tree is removed
  - Supports both `create` and `instance` parameters
- **ViewModelLocator**: Unified resolution checking scope → global → exception

#### UI Binding
- **Bind<TViewModel, TValue>**: Automatic one-way/two-way binding detection
  - Returns `ObservableProperty<T>` → two-way binding with `update` callback
  - Returns raw `T` → one-way binding (read-only)
  - Type-safe selector/builder contracts
- **Command<TViewModel>**: Command binding with automatic `canExecute` reactivity
- **CommandWithParam<TViewModel, TParam>**: Parameterized command binding

### Best Practices

- ⚠️ **Memory Leak Prevention**: Always capture disposer from `listen()` calls
- Use `Bind` and `Command` widgets for UI (automatic lifecycle management)
- `FairyScope` handles disposal for VMs created via `create` parameter
- Call `command.refresh()` when `canExecute` dependencies change
- Selectors must return stable property references

### Documentation

- Comprehensive README with quick start guide
- Best practices section with memory leak warnings
- Complete API reference with examples
- Example app demonstrating MVVM patterns

### Testing

- 257 unit and widget tests with 100% passing rate
- Tests cover all core primitives, DI patterns, and UI bindings
- Test structure mirrors library organization
