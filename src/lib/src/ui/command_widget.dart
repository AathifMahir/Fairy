import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import '../core/command.dart';
import '../locator/fairy_resolver.dart';

/// A widget that binds a [RelayCommand] or [AsyncRelayCommand] to UI.
///
/// [Command] extracts a command from a ViewModel and subscribes to its changes,
/// automatically rebuilding when [canExecute] changes. It provides both the
/// [execute] callback and [canExecute] state to the builder.
///
/// This widget works with:
/// - [RelayCommand]
/// - [AsyncRelayCommand]
/// - [RelayCommandWithParam<T>]
/// - [AsyncRelayCommandWithParam<T>]
///
/// ## Basic Example (RelayCommand):
/// ```dart
/// class MyViewModel extends ObservableObject {
///   late final ObservableProperty<String> userName;
///   late final RelayCommand saveCommand;
///   VoidCallback? _disposer;
///
///   MyViewModel() {
///     userName = ObservableProperty<String>('', parent: this);
///     
///     saveCommand = RelayCommand(
///       execute: _save,
///       canExecute: () => userName.value.isNotEmpty,
///       parent: this,
///     );
///     
///     _disposer = userName.propertyChanged(() => saveCommand.notifyCanExecuteChanged());
///   }
///
///   void _save() { /* ... */ }
///   
///   @override
///   void dispose() {
///     _disposer?.call();
///     super.dispose();
///   }
/// }
///
/// Command<MyViewModel>(
///   command: (vm) => vm.saveCommand,
///   builder: (context, execute, canExecute) {
///     return ElevatedButton(
///       onPressed: canExecute ? execute : null,
///       child: const Text('Save'),
///     );
///   },
/// )
/// ```
///
/// ## Async Example (AsyncRelayCommand):
/// ```dart
/// class DataViewModel extends ObservableObject {
///   late final AsyncRelayCommand fetchCommand;
///
///   DataViewModel() {
///     fetchCommand = AsyncRelayCommand(
///       execute: _fetchData,
///       parent: this,
///     );
///   }
///
///   Future<void> _fetchData() async { /* ... */ }
/// }
///
/// Command<DataViewModel>(
///   command: (vm) => vm.fetchCommand,
///   builder: (context, execute, canExecute) {
///     final vm = Fairy.of<DataViewModel>(context);
///     if (vm.fetchCommand.isRunning) {
///       return const CircularProgressIndicator();
///     }
///     return ElevatedButton(
///       onPressed: canExecute ? execute : null,
///       child: const Text('Fetch'),
///     );
///   },
/// )
/// ```
class Command<TViewModel extends ObservableObject> extends StatefulWidget {

  const Command({
    required this.command, required this.builder, super.key,
  });

  /// Creates a command binding for parameterized commands.
  ///
  /// This is a convenience factory that creates a [CommandWithParam] widget.
  /// Use when your command requires a parameter at execution time.
  ///
  /// Supports both [RelayCommandWithParam] and [AsyncRelayCommandWithParam].
  ///
  /// Example:
  /// ```dart
  /// Command.param<TodoViewModel, String>(
  ///   command: (vm) => vm.deleteTodoCommand,
  ///   parameter: todoId,
  ///   builder: (context, execute, canExecute) {
  ///     return IconButton(
  ///       onPressed: canExecute ? execute : null,
  ///       icon: const Icon(Icons.delete),
  ///     );
  ///   },
  /// )
  /// ```
  static CommandWithParam<TViewModel, TParam> param<TViewModel extends ObservableObject, TParam>({
    Key? key,
    required dynamic Function(TViewModel vm) command,
    required TParam parameter,
    required Widget Function(BuildContext context, VoidCallback execute, bool canExecute) builder,
  }) {
    return CommandWithParam<TViewModel, TParam>(
      key: key,
      command: command,
      parameter: parameter,
      builder: builder,
    );
  }

  /// Selector function that extracts the command from the ViewModel.
  ///
  /// Must return a [RelayCommand] or [AsyncRelayCommand] instance.
  ///
  /// **Important:** Should return a stable reference to the command,
  /// not create a new command instance each time.
  final dynamic Function(TViewModel vm) command;

  /// Builder function that constructs the UI.
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [execute]: Callback to execute the command
  /// - [canExecute]: Whether the command can currently execute
  final Widget Function(
    BuildContext context,
    VoidCallback execute,
    bool canExecute,
  ) builder;

  @override
  State<Command<TViewModel>> createState() => _CommandState<TViewModel>();
}

class _CommandState<TViewModel extends ObservableObject>
    extends State<Command<TViewModel>> {
  late TViewModel _viewModel;
  late dynamic _commandInstance; // RelayCommand or AsyncRelayCommand
  VoidCallback? _listener;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Don't resolve ViewModel here - violates InheritedWidget rules
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_initialized) {
      // Resolve ViewModel
      _viewModel = Fairy.of<TViewModel>(context);

      // Extract command
      _commandInstance = widget.command(_viewModel);

      // Subscribe to command changes (canExecute changes)
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
      
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(Command<TViewModel> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If command selector changed, rebind
    if (oldWidget.command != widget.command) {
      _removeListener();
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_listener != null) {
      _commandInstance.removeListener(_listener);
      _listener = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract execute and canExecute from command
    final VoidCallback execute;
    final bool canExecute;

    if (_commandInstance is RelayCommand) {
      final cmd = _commandInstance as RelayCommand;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
    } else if (_commandInstance is AsyncRelayCommand) {
      final cmd = _commandInstance as AsyncRelayCommand;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
    } else {
      throw StateError(
        'Command selector must return a RelayCommand or AsyncRelayCommand. '
        'Got: ${_commandInstance.runtimeType}',
      );
    }

    return widget.builder(context, execute, canExecute);
  }
}

/// A widget that binds a parameterized command to UI.
///
/// Similar to [Command], but for [RelayCommandWithParam<T>] and
/// [AsyncRelayCommandWithParam<T>] that require parameters.
///
/// Example:
/// ```dart
/// class TodoViewModel extends ObservableObject {
///   late final RelayCommandWithParam<String> deleteTodoCommand;
///
///   TodoViewModel() {
///     deleteTodoCommand = RelayCommandWithParam<String>(
///       execute: _deleteTodo,
///       parent: this,
///     );
///   }
///
///   void _deleteTodo(String id) { /* ... */ }
/// }
///
/// CommandWithParam<TodoViewModel, String>(
///   command: (vm) => vm.deleteTodoCommand,
///   parameter: todoId,
///   builder: (context, execute, canExecute) {
///     return IconButton(
///       onPressed: canExecute ? execute : null,
///       icon: const Icon(Icons.delete),
///     );
///   },
/// )
/// ```
class CommandWithParam<TViewModel extends ObservableObject, TParam>
    extends StatefulWidget {

  const CommandWithParam({
    super.key,
    required this.command,
    required this.parameter,
    required this.builder,
  });
  /// Selector function that extracts the parameterized command.
  final dynamic Function(TViewModel vm) command;

  /// The parameter to pass to the command when executed.
  final TParam parameter;

  /// Builder function that constructs the UI.
  final Widget Function(
    BuildContext context,
    VoidCallback execute,
    bool canExecute,
  ) builder;

  @override
  State<CommandWithParam<TViewModel, TParam>> createState() =>
      _CommandWithParamState<TViewModel, TParam>();
}

class _CommandWithParamState<TViewModel extends ObservableObject, TParam>
    extends State<CommandWithParam<TViewModel, TParam>> {
  late TViewModel _viewModel;
  late dynamic _commandInstance;
  VoidCallback? _listener;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Don't resolve ViewModel here - violates InheritedWidget rules
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_initialized) {
      _viewModel = Fairy.of<TViewModel>(context);
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(CommandWithParam<TViewModel, TParam> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.command != widget.command) {
      _removeListener();
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_listener != null) {
      _commandInstance.removeListener(_listener);
      _listener = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback execute;
    final bool canExecute;

    if (_commandInstance is RelayCommandWithParam<TParam>) {
      final cmd = _commandInstance as RelayCommandWithParam<TParam>;
      execute = () => cmd.execute(widget.parameter);
      canExecute = cmd.canExecute(widget.parameter);
    } else if (_commandInstance is AsyncRelayCommandWithParam<TParam>) {
      final cmd = _commandInstance as AsyncRelayCommandWithParam<TParam>;
      execute = () => cmd.execute(widget.parameter);
      canExecute = cmd.canExecute(widget.parameter);
    } else {
      throw StateError(
        'Command selector must return a RelayCommandWithParam<$TParam> or AsyncRelayCommandWithParam<$TParam>. '
        'Got: ${_commandInstance.runtimeType}',
      );
    }

    return widget.builder(context, execute, canExecute);
  }
}
