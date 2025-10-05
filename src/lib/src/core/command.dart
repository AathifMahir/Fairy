import 'package:flutter/foundation.dart';

/// Callback type for evaluating whether a command can execute.
typedef CanExecute = bool Function();

/// A command that encapsulates an action with optional execution guard logic.
///
/// [RelayCommand] implements the command pattern for ViewModels, allowing you
/// to bind user actions to methods with optional `canExecute` validation.
///
/// The command notifies listeners when `canExecute` might have changed, enabling
/// UI elements (like buttons) to reactively enable/disable themselves.
///
/// Example:
/// ```dart
/// class MyViewModel extends ObservableObject {
///   final userName = ObservableProperty<String>('');
///   late final RelayCommand saveCommand;
///
///   MyViewModel() {
///     saveCommand = RelayCommand(
///       _save,
///       canExecute: () => userName.value.isNotEmpty,
///     );
///
///     // Refresh command when validation state changes
///     userName.addListener(() => saveCommand.refresh());
///   }
///
///   void _save() {
///     // Save logic here
///   }
/// }
/// ```
class RelayCommand extends ChangeNotifier {

  /// Creates a [RelayCommand] with an action and optional canExecute predicate.
  ///
  /// [action] is the method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// If omitted, the command can always execute.
  RelayCommand(this._action, {CanExecute? canExecute})
      : _canExecute = canExecute;
  final VoidCallback _action;
  final CanExecute? _canExecute;

  /// Whether the command can currently execute.
  ///
  /// Returns `true` if no [canExecute] predicate was provided, or if the
  /// predicate returns `true`.
  bool get canExecute => _canExecute?.call() ?? true;

  /// Executes the command's action if [canExecute] is `true`.
  ///
  /// Does nothing if [canExecute] returns `false`.
  void execute() {
    if (canExecute) {
      _action();
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions for [canExecute] change (e.g., when
  /// a property that affects validation is updated).
  void refresh() => notifyListeners();

}

/// An asynchronous command that tracks execution state and prevents re-entry.
///
/// [AsyncRelayCommand] is designed for long-running async operations like
/// network calls or database queries. It automatically manages [isRunning] state
/// and prevents concurrent execution.
///
/// The command automatically disables itself ([canExecute] returns `false`)
/// while running to prevent duplicate executions.
///
/// Example:
/// ```dart
/// class DataViewModel extends ObservableObject {
///   final data = ObservableProperty<List<Item>?>([]);
///   late final AsyncRelayCommand fetchDataCommand;
///
///   DataViewModel() {
///     fetchDataCommand = AsyncRelayCommand(_fetchData);
///   }
///
///   Future<void> _fetchData() async {
///     final response = await api.fetchItems();
///     data.value = response;
///   }
/// }
///
/// // In UI:
/// // Command automatically shows isRunning state
/// if (viewModel.fetchDataCommand.isRunning) {
///   return CircularProgressIndicator();
/// }
/// ```
class AsyncRelayCommand extends ChangeNotifier {

  /// Creates an [AsyncRelayCommand] with an async action and optional canExecute predicate.
  ///
  /// [action] is the asynchronous method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// The command automatically disables during execution regardless of [canExecute].
  AsyncRelayCommand(this._action, {CanExecute? canExecute})
      : _canExecute = canExecute;
  final Future<void> Function() _action;
  final CanExecute? _canExecute;
  bool _isRunning = false;

  /// Whether the command is currently executing.
  ///
  /// This is automatically set to `true` when [execute] is called and reset
  /// to `false` when the action completes or throws an error.
  bool get isRunning => _isRunning;

  /// Whether the command can currently execute.
  ///
  /// Returns `false` if the command [isRunning] or if the [canExecute]
  /// predicate returns `false`.
  bool get canExecute => !_isRunning && (_canExecute?.call() ?? true);

  /// Executes the command's async action if [canExecute] is `true`.
  ///
  /// Automatically sets [isRunning] to `true` before execution and `false`
  /// after completion (including errors). Prevents re-entry if already running.
  ///
  /// Returns a [Future] that completes when the action completes.
  Future<void> execute() async {
    if (!canExecute) return;

    _isRunning = true;
    notifyListeners();

    try {
      await _action();
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions for the [canExecute] predicate change.
  void refresh() => notifyListeners();

}

/// A command that accepts a typed parameter when executing.
///
/// [RelayCommandWithParam] allows commands to receive input values, useful for
/// scenarios like item selection, delete operations with IDs, or any action
/// requiring contextual data.
///
/// Example:
/// ```dart
/// class TodoViewModel extends ObservableObject {
///   final todos = ObservableProperty<List<Todo>>([]);
///   late final RelayCommandWithParam<String> deleteTodoCommand;
///
///   TodoViewModel() {
///     deleteTodoCommand = RelayCommandWithParam<String>(
///       _deleteTodo,
///       canExecute: (id) => todos.value.any((t) => t.id == id),
///     );
///   }
///
///   void _deleteTodo(String id) {
///     todos.value = todos.value.where((t) => t.id != id).toList();
///   }
/// }
/// ```
class RelayCommandWithParam<TParam> extends ChangeNotifier {

  /// Creates a parameterized command with an action and optional canExecute predicate.
  ///
  /// [action] receives a parameter of type [TParam] when executed.
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  RelayCommandWithParam(this._action, {bool Function(TParam)? canExecute})
      : _canExecute = canExecute;
      
  final void Function(TParam) _action;
  final bool Function(TParam)? _canExecute;

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `true` if no [canExecute] predicate was provided, or if the
  /// predicate returns `true` for the given parameter.
  bool canExecute(TParam param) => _canExecute?.call(param) ?? true;

  /// Executes the command's action with the given [param] if [canExecute] is `true`.
  ///
  /// Does nothing if [canExecute] returns `false` for the parameter.
  void execute(TParam param) {
    if (canExecute(param)) {
      _action(param);
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions affecting [canExecute] change.
  void refresh() => notifyListeners();

}

/// An asynchronous command that accepts a typed parameter when executing.
///
/// Combines the features of [AsyncRelayCommand] and [RelayCommandWithParam],
/// providing async execution with parameter support and [isRunning] state tracking.
///
/// Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   late final AsyncRelayCommandWithParam<String> loadUserCommand;
///
///   UserViewModel() {
///     loadUserCommand = AsyncRelayCommandWithParam<String>(_loadUser);
///   }
///
///   Future<void> _loadUser(String userId) async {
///     final user = await api.fetchUser(userId);
///     // Update state
///   }
/// }
/// ```
class AsyncRelayCommandWithParam<TParam> extends ChangeNotifier {

  /// Creates an async parameterized command.
  ///
  /// [action] is an async function that receives a parameter of type [TParam].
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  AsyncRelayCommandWithParam(this._action,
      {bool Function(TParam)? canExecute})
      : _canExecute = canExecute;
      
  final Future<void> Function(TParam) _action;
  final bool Function(TParam)? _canExecute;
  bool _isRunning = false;

  /// Whether the command is currently executing.
  bool get isRunning => _isRunning;

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `false` if the command [isRunning] or if the [canExecute]
  /// predicate returns `false` for the parameter.
  bool canExecute(TParam param) =>
      !_isRunning && (_canExecute?.call(param) ?? true);

  /// Executes the command's async action with the given [param] if [canExecute] is `true`.
  ///
  /// Automatically manages [isRunning] state and prevents re-entry.
  Future<void> execute(TParam param) async {
    if (!canExecute(param)) {
      return;
    }

    _isRunning = true;
    notifyListeners();

    try {
      await _action(param);
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  void refresh() => notifyListeners();

}
