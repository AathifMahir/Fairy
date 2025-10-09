# Fairy – AI Agent Instructions

Fairy is a lightweight MVVM framework for Flutter with reactive data binding, command patterns, and dependency injection. No build_runner required.

## Architecture Layers

1. **Core** (`lib/src/core/`): `ObservableObject`, `ObservableProperty<T>`, `RelayCommand`, `AsyncRelayCommand`, `RelayCommandWithParam<T>`, `AsyncRelayCommandWithParam<T>`, `ComputedProperty<T>`
2. **Locator** (`lib/src/locator/`): `FairyLocator` (global DI), `FairyScope` (scoped DI), `Fairy` (resolver)
3. **UI** (`lib/src/ui/`): `Bind<TViewModel, TValue>` (data binding), `Command<TViewModel>` (command binding), `CommandWithParam<TViewModel, TParam>` (parameterized command binding)

## Key Rules

- **Bind auto-detection**: Returns `ObservableProperty<T>` → two-way binding; Returns raw `T` → one-way binding
- **DI resolution order**: `FairyScope` (nearest) → `FairyLocator` (global) → exception
- **Disposal**: `FairyScope` only disposes VMs it created via `create` parameter (when `autoDispose: true`)
- **Auto-disposal**: Properties and commands created with `parent` parameter are auto-disposed when parent is disposed
- **Observable API**: Use `onPropertyChanged()` for notifications, `propertyChanged(listener)` returns disposer (MUST capture to avoid memory leaks)
- **Named parameters**: All command constructors use named parameters: `execute:`, `canExecute:`, `parent:`
- **Parent parameter**: ObservableProperty, ComputedProperty, and all command types accept optional `parent: ObservableObject?` parameter for auto-disposal

## Critical Patterns

### ViewModels
- Use `final` fields with `ObservableProperty<T>(initialValue, parent: this)` for auto-disposal
- Pass `parent: this` to properties/commands created in constructor to enable auto-disposal
- Nested `ObservableObject` instances require manual disposal in `dispose()` override
- Call `command.notifyCanExecuteChanged()` when `canExecute` dependencies change
- Selectors MUST return stable property references (never create new instances)

### Commands
- `RelayCommand`: Sync actions with optional `canExecute` - use: `RelayCommand(execute: () => action, canExecute: () => condition, parent: this)`
- `AsyncRelayCommand`: Async actions with auto `isRunning` state - use: `AsyncRelayCommand(execute: () async => action, parent: this)`
- `RelayCommandWithParam<T>`: Parameterized commands - use: `RelayCommandWithParam<T>(execute: (param) => action, parent: this)`
- `AsyncRelayCommandWithParam<T>`: Async parameterized commands - use: `AsyncRelayCommandWithParam<T>(execute: (param) async => action, parent: this)`
- Call `notifyCanExecuteChanged()` to re-evaluate `canExecute` after dependency changes
- Use `canExecuteChanged(listener)` to subscribe to `canExecute` changes (returns disposer function, similar to `propertyChanged()`)

### Memory Management
- **CRITICAL**: Always capture disposer from `propertyChanged()` and `canExecuteChanged()` calls to avoid memory leaks
- Pass `parent: this` parameter when creating properties/commands for automatic disposal
- Use `Bind`/`Command` widgets for UI (handles lifecycle automatically)
- `FairyScope` auto-disposes VMs created via `create` parameter (when `autoDispose: true`)
- ChangeNotifier API is `@protected` in all types - do not call `addListener`/`removeListener` directly

## Common Pitfalls

1. **Memory leaks**: Not capturing `propertyChanged()` disposer → listener stays forever
2. **Unstable selectors**: Creating new `ObservableProperty` in selector → infinite rebuilds
3. **Missing refresh**: Not calling `notifyCanExecuteChanged()` when `canExecute` dependencies change
4. **Manual disposal of scoped VMs**: Let `FairyScope` handle disposal automatically
5. **Wrong constructor syntax**: Remember to use named parameters: `execute:`, `canExecute:`, `parent:`
6. **Forgetting parent parameter**: Not passing `parent: this` prevents auto-disposal (debug warning will show)

## Testing

- Unit tests: Mirror `lib/src/` structure in `test/` directory
- Widget tests: Use `FairyScope` with test ViewModels
- Verify: Property changes trigger rebuilds, commands respect `canExecute`, VMs are disposed
