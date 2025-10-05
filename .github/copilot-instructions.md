# Fairy – AI Agent Instructions

Fairy is a lightweight MVVM framework for Flutter with reactive data binding, command patterns, and dependency injection. No build_runner required.

## Architecture Layers

1. **Core** (`lib/src/core/`): `ObservableObject`, `ObservableProperty<T>`, `RelayCommand`, `AsyncRelayCommand`, `ComputedProperty<T>`
2. **Locator** (`lib/src/locator/`): `FairyLocator` (global DI), `FairyScope` (scoped DI), `ViewModelLocator` (resolver)
3. **UI** (`lib/src/ui/`): `Bind<TViewModel, TValue>` (data binding), `Command<TViewModel>` (command binding)

## Key Rules

- **Bind auto-detection**: Returns `ObservableProperty<T>` → two-way binding; Returns raw `T` → one-way binding
- **DI resolution order**: `FairyScope` (nearest) → `FairyLocator` (global) → exception
- **Disposal**: `FairyScope` only disposes VMs it created via `create` parameter
- **Observable API**: Use `onPropertyChanged()` for notifications, `listen()` returns disposer (MUST capture to avoid memory leaks)

## Critical Patterns

### ViewModels
- Use `final` fields with `ObservableProperty<T>(initialValue)`
- Always dispose properties in `dispose()` override
- Call `command.refresh()` when `canExecute` dependencies change
- Selectors MUST return stable property references (never create new instances)

### Commands
- `RelayCommand`: Sync actions with optional `canExecute`
- `AsyncRelayCommand`: Async actions with auto `isRunning` state
- `RelayCommandWithParam<T>`: Parameterized commands
- Call `refresh()` to re-evaluate `canExecute` after dependency changes

### Memory Management
- **CRITICAL**: Always capture disposer from `listen()` and call it in `dispose()` to avoid memory leaks
- Use `Bind`/`Command` widgets for UI (handles lifecycle automatically)
- `FairyScope` auto-disposes VMs created via `create` parameter

## Common Pitfalls

1. **Memory leaks**: Not capturing `listen()` disposer → listener stays forever
2. **Unstable selectors**: Creating new `ObservableProperty` in selector → infinite rebuilds
3. **Missing refresh**: Not calling `command.refresh()` when `canExecute` dependencies change
4. **Manual disposal of scoped VMs**: Let `FairyScope` handle disposal automatically

## Testing

- Unit tests: Mirror `lib/src/` structure in `test/` directory
- Widget tests: Use `FairyScope` with test ViewModels
- Verify: Property changes trigger rebuilds, commands respect `canExecute`, VMs are disposed
