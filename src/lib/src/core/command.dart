import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/core/observable_node.dart';
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
///   late final ObservableProperty<String> userName;
///   late final RelayCommand saveCommand;
///   VoidCallback? _disposer;
///
///   MyViewModel() {
///     userName = ObservableProperty<String>('');
///     
///     saveCommand = RelayCommand(
///       _save,
///       canExecute: () => userName.value.isNotEmpty,
///     );
///
///     // Refresh command when validation state changes
///     _disposer = userName.propertyChanged(() => saveCommand.notifyCanExecuteChanged());
///   }
///
///   void _save() {
///     // Save logic here
///   }
///   
///   @override
///   void dispose() {
///     _disposer?.call();
///     super.dispose();
///   }
/// }
/// ```
class RelayCommand extends ObservableNode {

  final VoidCallback _action;
  final CanExecute? _canExecute;

  /// Creates a [RelayCommand] with an action and optional canExecute predicate.
  ///
  /// [execute] is the method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// If omitted, the command can always execute.
  RelayCommand(
    VoidCallback execute, {
    CanExecute? canExecute,
  })  : _action = execute,
        _canExecute = canExecute;

    // ========================================================================
  // HIDDEN ChangeNotifier API (marked @protected for internal framework use)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

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
  void notifyCanExecuteChanged() => notifyListeners();


  /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = RelayCommand(() { /* ... */ });
  /// 
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  /// 
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }

}

/// An asynchronous command for long-running operations.
///
/// [AsyncRelayCommand] is designed for async operations like network calls
/// or database queries. Unlike [RelayCommand], it returns a [Future] from
/// [execute] that completes when the async action finishes.
///
/// **Automatic Loading State:** The [isRunning] property automatically tracks
/// execution state. While running, [canExecute] returns `false` to prevent
/// concurrent execution (double-click prevention).
///
/// Example:
/// ```dart
/// class DataViewModel extends ObservableObject {
///   late final ObservableProperty<List<Item>?> data;
///   late final AsyncRelayCommand fetchDataCommand;
///
///   DataViewModel() {
///     data = ObservableProperty<List<Item>?>([]);
///     
///     fetchDataCommand = AsyncRelayCommand(
///       _fetchData,
///     );
///   }
///
///   Future<void> _fetchData() async {
///     // isRunning automatically set to true
///     final response = await api.fetchItems();
///     data.value = response;
///     // isRunning automatically set to false
///   }
/// }
///
/// // In UI - use isRunning for loading indicators
/// Command<DataViewModel>(
///   command: (vm) => vm.fetchDataCommand,
///   builder: (context, execute, canExecute, isRunning) {
///     if (isRunning) return CircularProgressIndicator();
///     return ElevatedButton(onPressed: execute, child: Text('Fetch'));
///   },
/// )
/// ```
class AsyncRelayCommand extends ObservableNode {

  final Future<void> Function() _action;
  final CanExecute? _canExecute;
  bool _isRunning = false;

  /// Creates an [AsyncRelayCommand] with an async action and optional canExecute predicate.
  ///
  /// [execute] is the asynchronous method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// 
  /// While the command is executing, [isRunning] is `true` and [canExecute]
  /// automatically returns `false` to prevent concurrent execution.
  AsyncRelayCommand(
    Future<void> Function() execute, {
    CanExecute? canExecute,
  })  : _action = execute,
        _canExecute = canExecute;

    // ========================================================================
  // HIDDEN ChangeNotifier API (marked @protected for internal framework use)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command is currently executing.
  /// 
  /// Automatically set to `true` when execution starts and `false` when it completes.
  /// While running, [canExecute] returns `false` to prevent concurrent execution.
  bool get isRunning => _isRunning;

  /// Whether the command can currently execute.
  ///
  /// Returns `false` if the command is currently running, or if the [canExecute]
  /// predicate returns `false`.
  bool get canExecute => !_isRunning && (_canExecute?.call() ?? true);

  /// Executes the command's async action if [canExecute] is `true`.
  ///
  /// Returns a [Future] that completes when the action completes.
  /// Sets [isRunning] to `true` during execution and `false` when complete.
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
  void notifyCanExecuteChanged() => notifyListeners();

    /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = AsyncRelayCommand(() { /* ... */ });
  /// 
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  /// 
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }

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
///   late final ObservableProperty<List<Todo>> todos;
///   late final RelayCommandWithParam<String> deleteTodoCommand;
///
///   TodoViewModel() {
///     todos = ObservableProperty<List<Todo>>([]);
///     
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
class RelayCommandWithParam<TParam> extends ObservableNode {

  final void Function(TParam) _action;
  final bool Function(TParam)? _canExecute;

  /// Creates a parameterized relay command.
  ///
  /// [execute] receives a parameter of type [TParam] when executed.
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  RelayCommandWithParam(
    void Function(TParam) execute, {
    bool Function(TParam)? canExecute,
  })  : _action = execute,
        _canExecute = canExecute;


    // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `true` if no [canExecute] predicate was provided, or if the
  /// predicate returns `true` for the given parameter.
  /// 
  /// Note: This is a method (not a getter), so automatic tracking is not applied.
  /// Subscribe to canExecuteChanged() for manual tracking if needed.
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
  void notifyCanExecuteChanged() => notifyListeners();

    /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = RelayCommandWithParam<String>(() { /* ... */ });
  /// 
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  /// 
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }

}

/// An asynchronous command that accepts a typed parameter when executing.
///
/// Combines the features of [AsyncRelayCommand] and [RelayCommandWithParam],
/// providing async execution with parameter support and optional [canExecute] validation.
///
/// **Automatic Loading State:** The [isRunning] property automatically tracks
/// execution state. While running, [canExecute] returns `false` to prevent
/// concurrent execution (double-click prevention).
///
/// Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   late final AsyncRelayCommandWithParam<String> loadUserCommand;
///
///   UserViewModel() {
///     loadUserCommand = AsyncRelayCommandWithParam<String>(
///       _loadUser,
///       canExecute: (userId) => userId.isNotEmpty,
///     );
///   }
///
///   Future<void> _loadUser(String userId) async {
///     // isRunning automatically set to true
///     final user = await api.fetchUser(userId);
///     // Update state
///     // isRunning automatically set to false
///   }
/// }
///
/// // In UI
/// Command.param<UserViewModel, String>(
///   command: (vm) => vm.loadUserCommand,
///   parameter: () => userId,
///   builder: (context, execute, canExecute, isRunning) {
///     if (isRunning) return CircularProgressIndicator();
///     return ElevatedButton(onPressed: execute, child: Text('Load'));
///   },
/// )
/// ```
class AsyncRelayCommandWithParam<TParam> extends ObservableNode {

  final Future<void> Function(TParam) _action;
  final bool Function(TParam)? _canExecute;
  bool _isRunning = false;

  /// Creates an async parameterized command.
  ///
  /// [execute] is an async function that receives a parameter of type [TParam].
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  /// 
  /// While the command is executing, [isRunning] is `true` and [canExecute]
  /// automatically returns `false` to prevent concurrent execution.
  AsyncRelayCommandWithParam(
    Future<void> Function(TParam) execute, {
    bool Function(TParam)? canExecute,
  })  : _action = execute,
        _canExecute = canExecute;


  // ========================================================================
  // HIDDEN ChangeNotifier API (marked @protected for internal framework use)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command is currently executing.
  /// 
  /// Automatically set to `true` when execution starts and `false` when it completes.
  /// While running, [canExecute] returns `false` to prevent concurrent execution.
  bool get isRunning => _isRunning;

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `false` if the command is currently running, or if the [canExecute]
  /// predicate returns `false` for the parameter.
  /// 
  /// Note: This method takes a parameter, so automatic tracking is not applied.
  /// For automatic dependency tracking, observe properties that affect canExecute.
  bool canExecute(TParam param) => !_isRunning && (_canExecute?.call(param) ?? true);

  /// Executes the command's async action with the given [param] if [canExecute] is `true`.
  /// 
  /// Sets [isRunning] to `true` during execution and `false` when complete.
  Future<void> execute(TParam param) async {
    if (!canExecute(param)) return;
    
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
  void notifyCanExecuteChanged() => notifyListeners();


    /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = AsyncRelayCommandWithParam<String>(() { /* ... */ });
  /// 
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  /// 
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }

}
