import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/core/observable_node.dart';
import 'package:fairy/src/internal/dependency_tracker.dart';
import 'package:fairy/src/locator/fairy_resolver.dart';
import 'package:flutter/widgets.dart';

/// A widget that automatically binds based on Property that's been accessed
/// accessed during its builder function, plus the ViewModel itself.
///
/// This is Fairy's equivalent to Provider's Consumer or Riverpod's ConsumerWidget.
/// Unlike the standard [Bind] widget which requires explicit selectors, [BindViewModel]
/// automatically tracks which properties and commands are bound and only rebuilds
/// when those specific nodes change.
///
/// **Important:** The widget ALWAYS subscribes to the ViewModel itself in addition
/// to any [ObservableProperty] or command instances accessed. This ensures that
/// regular fields (non-observable) and direct [onPropertyChanged] calls trigger rebuilds.
///
/// ## When to Use
///
/// - **Multiple properties**: Binding several properties from the same ViewModel
/// - **Dynamic access**: Conditional branches that access different properties
/// - **Command state**: Track [AsyncRelayCommand.isRunning] or [RelayCommand.canExecute]
/// - **Regular fields**: ViewModels with non-observable fields using [onPropertyChanged]
/// - **Rapid prototyping**: Avoid writing explicit selectors during development
///
/// ## When NOT to Use
///
/// - **Single property**: Use standard `Bind<TViewModel, TValue>` for better performance
/// - **Performance-critical**: Explicit selectors have 5-10% less overhead
///
/// ## Example
///
/// ```dart
/// class CounterViewModel extends ObservableObject {
///   late final ObservableProperty<int> count;
///   late final ObservableProperty<String> message;
///   late final AsyncRelayCommand saveCommand;
///
///   // Regular field (not ObservableProperty)
///   int _regularField = 0;
///   int get regularField => _regularField;
///
///   CounterViewModel() {
///     count = ObservableProperty<int>(0);
///     message = ObservableProperty<String>('');
///     saveCommand = AsyncRelayCommand(_save);
///   }
///
///   void updateRegularField(int value) {
///     _regularField = value;
///     onPropertyChanged(); // ✅ Will trigger rebuild
///   }
///
///   Future<void> _save() async {
///     // Save logic
///   }
/// }
///
/// // UI - automatically tracks:
/// // - ViewModel itself (for regularField via onPropertyChanged)
/// // - count ObservableProperty
/// // - message ObservableProperty
/// // - saveCommand.isRunning
/// BindViewModel<CounterViewModel>(
///   builder: (context, vm) {
///     return Column(
///       children: [
///         Text('Count: ${vm.count.value}'),
///         Text('Message: ${vm.message.value}'),
///         Text('Regular: ${vm.regularField}'), // ✅ Works!
///         if (vm.saveCommand.isRunning)
///           CircularProgressIndicator(),
///       ],
///     );
///   },
/// )
/// ```
///
/// ## How It Works
///
/// During the build phase, [BindViewModel] creates a tracking session via
/// [DependencyTracker]. The widget automatically reports two types of accesses:
///
/// 1. **ViewModel access**: Always tracked at the start of build to catch
///    regular field changes and direct [onPropertyChanged] calls
/// 2. **Property/Command access**: When you read `vm.count.value`, the getter
///    calls `DependencyTracker.reportAccess(this)`, adding the property to the session
///
/// After build completes, the widget subscribes to all accessed nodes
/// (ViewModel + properties + commands). This ensures rebuilds happen for:
/// - Observable property changes (via [ObservableProperty.value] setter)
/// - Command state changes (via [AsyncRelayCommand.isRunning])
/// - Regular field changes (via [ObservableObject.onPropertyChanged])
///
/// ## Performance Characteristics
///
/// - **Frame coalescing**: Multiple rapid changes trigger only one rebuild per frame
/// - **Dual subscription**: Subscribes to ViewModel + accessed properties/commands
/// - **Conditional optimization**: Properties in `if` branches only tracked when executed
/// - **Overhead**: ~5-10% slower than explicit selectors due to tracking infrastructure
class BindViewModel<TViewModel extends ObservableObject>
    extends StatefulWidget {
  /// The builder function that receives the resolved ViewModel.
  ///
  /// All [ObservableProperty] and command getters accessed during this function
  /// will be automatically tracked for change notifications.
  final Widget Function(BuildContext context, TViewModel vm) builder;

  /// Creates a [BindViewModel] widget.
  ///
  /// The [builder] function is called with the resolved ViewModel from the
  /// nearest [FairyScope] or [FairyLocator]. Property and command accesses
  /// during build are automatically tracked.
  const BindViewModel({
    super.key,
    required this.builder,
  });

  @override
  State<BindViewModel<TViewModel>> createState() =>
      _BindViewModelState<TViewModel>();
}

class _BindViewModelState<TViewModel extends ObservableObject>
    extends State<BindViewModel<TViewModel>> {
  /// Current subscriptions (for cleanup)
  final List<VoidCallback> _disposers = [];

  /// Current set of tracked nodes (for diffing)
  final Set<ObservableNode> _currentNodes = {};

  /// Called when any subscribed ObservableNode changes.
  ///
  /// Calls setState immediately to trigger a rebuild. Flutter's framework
  /// will batch multiple setState calls that happen in the same frame,
  /// so this provides natural coalescing without explicit async batching.
  void _onNodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    // Clean up all subscriptions
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _currentNodes.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve ViewModel using Fairy's DI system
    final vm = Fairy.of<TViewModel>(context);

    Widget built;
    Set<ObservableNode> accessed;

    try {
      // Track dependencies during build
      (built, accessed) = DependencyTracker.track(() {
        // ✅ Always report ViewModel access at the start
        // This ensures we catch regular field changes via onPropertyChanged()
        DependencyTracker.reportAccess(vm);

        return widget.builder(context, vm);
      });
    } catch (error) {
      // ✅ CRITICAL: Capture partial tracking on exception
      // This ensures subscriptions are reconciled even if build fails
      accessed = DependencyTracker.captureAccessed();

      // Reconcile with partial tracking before re-throwing
      _reconcileSubscriptions(accessed);

      rethrow;
    }

    // Reconcile subscriptions after successful build
    _reconcileSubscriptions(accessed);

    return built;
  }

  /// Updates subscriptions to match newly accessed nodes.
  ///
  /// Performs a diff between the previous set of tracked nodes and the new set,
  /// adding subscriptions for newly accessed nodes and removing subscriptions
  /// for nodes that are no longer accessed.
  ///
  /// For simplicity when nodes are removed, all subscriptions are disposed and
  /// recreated rather than tracking which disposer belongs to which node.
  void _reconcileSubscriptions(Set<ObservableNode> accessed) {
    // Early exit optimization - no changes needed
    if (_currentNodes.length == accessed.length &&
        _currentNodes.containsAll(accessed)) {
      return;
    }

    // Find nodes no longer accessed
    final removed = _currentNodes.difference(accessed);

    // Find newly accessed nodes
    final added = accessed.difference(_currentNodes);

    if (removed.isNotEmpty) {
      // Clean slate approach: dispose all and recreate
      // This is simpler than tracking disposer→node mappings
      for (final disposer in _disposers) {
        disposer();
      }
      _disposers.clear();

      // Re-subscribe to all currently accessed nodes
      for (final node in accessed) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    } else if (added.isNotEmpty) {
      // Only add new subscriptions (no removals needed)
      for (final node in added) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    }

    // Update snapshot
    _currentNodes
      ..clear()
      ..addAll(accessed);
  }

  /// Creates a subscription to an ObservableNode.
  ///
  /// Uses the protected addListener API since we're in framework code.
  /// Returns a disposer function that removes the listener.
  VoidCallback _createSubscription(ObservableNode node) {
    node.addListener(_onNodeChanged);
    return () => node.removeListener(_onNodeChanged);
  }
}

/// A widget that automatically binds based on Property that's been accessed
/// from two ViewModels accessed during its builder function.
///
/// This is the two-ViewModel variant of [BindViewModel]. Use when you need to
/// bind multiple properties at once from multiple ViewModels simultaneously.
///
/// Example:
/// ```dart
/// BindViewModel2<UserViewModel, SettingsViewModel>(
///   builder: (context, user, settings) {
///     return Column(
///       children: [
///         Text('User: ${user.name.value}'),
///         Text('Theme: ${settings.theme.value}'),
///       ],
///     );
///   },
/// )
/// ```
class BindViewModel2<TViewModel1 extends ObservableObject,
    TViewModel2 extends ObservableObject> extends StatefulWidget {
  /// The builder function that receives two resolved ViewModels.
  final Widget Function(
    BuildContext context,
    TViewModel1 vm1,
    TViewModel2 vm2,
  ) builder;

  const BindViewModel2({
    super.key,
    required this.builder,
  });

  @override
  State<BindViewModel2<TViewModel1, TViewModel2>> createState() =>
      _BindViewModel2State<TViewModel1, TViewModel2>();
}

class _BindViewModel2State<TViewModel1 extends ObservableObject,
        TViewModel2 extends ObservableObject>
    extends State<BindViewModel2<TViewModel1, TViewModel2>> {
  final List<VoidCallback> _disposers = [];
  final Set<ObservableNode> _currentNodes = {};

  void _onNodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _currentNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm1 = Fairy.of<TViewModel1>(context);
    final vm2 = Fairy.of<TViewModel2>(context);

    Widget built;
    Set<ObservableNode> accessed;

    try {
      (built, accessed) = DependencyTracker.track(() {
        // ✅ Always report ViewModels access
        DependencyTracker.reportAccess(vm1);
        DependencyTracker.reportAccess(vm2);

        return widget.builder(context, vm1, vm2);
      });
    } catch (error) {
      accessed = DependencyTracker.captureAccessed();
      _reconcileSubscriptions(accessed);
      rethrow;
    }

    _reconcileSubscriptions(accessed);
    return built;
  }

  void _reconcileSubscriptions(Set<ObservableNode> accessed) {
    if (_currentNodes.length == accessed.length &&
        _currentNodes.containsAll(accessed)) {
      return;
    }

    final removed = _currentNodes.difference(accessed);

    if (removed.isNotEmpty) {
      for (final disposer in _disposers) {
        disposer();
      }
      _disposers.clear();

      for (final node in accessed) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    } else {
      final added = accessed.difference(_currentNodes);
      for (final node in added) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    }

    _currentNodes
      ..clear()
      ..addAll(accessed);
  }

  VoidCallback _createSubscription(ObservableNode node) {
    node.addListener(_onNodeChanged);
    return () => node.removeListener(_onNodeChanged);
  }
}

/// A widget that automatically binds based on Property that's been accessed
/// from three ViewModels accessed during its builder function.
///
/// This is the three-ViewModel variant of [BindViewModel]. Use when you need to
/// bind multiple properties at once from multiple ViewModels simultaneously.
///
/// Example:
/// ```dart
/// BindViewModel3<UserViewModel, SettingsViewModel, DataViewModel>(
///   builder: (context, user, settings, data) {
///     return Column(
///       children: [
///         Text('User: ${user.name.value}'),
///         Text('Theme: ${settings.theme.value}'),
///         Text('Count: ${data.count.value}'),
///       ],
///     );
///   },
/// )
/// ```
class BindViewModel3<
    TViewModel1 extends ObservableObject,
    TViewModel2 extends ObservableObject,
    TViewModel3 extends ObservableObject> extends StatefulWidget {
  /// The builder function that receives three resolved ViewModels.
  final Widget Function(
    BuildContext context,
    TViewModel1 vm1,
    TViewModel2 vm2,
    TViewModel3 vm3,
  ) builder;

  const BindViewModel3({
    super.key,
    required this.builder,
  });

  @override
  State<BindViewModel3<TViewModel1, TViewModel2, TViewModel3>> createState() =>
      _BindViewModel3State<TViewModel1, TViewModel2, TViewModel3>();
}

class _BindViewModel3State<
        TViewModel1 extends ObservableObject,
        TViewModel2 extends ObservableObject,
        TViewModel3 extends ObservableObject>
    extends State<BindViewModel3<TViewModel1, TViewModel2, TViewModel3>> {
  final List<VoidCallback> _disposers = [];
  final Set<ObservableNode> _currentNodes = {};

  void _onNodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _currentNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm1 = Fairy.of<TViewModel1>(context);
    final vm2 = Fairy.of<TViewModel2>(context);
    final vm3 = Fairy.of<TViewModel3>(context);

    Widget built;
    Set<ObservableNode> accessed;

    try {
      (built, accessed) = DependencyTracker.track(() {
        // ✅ Always report ViewModels access
        DependencyTracker.reportAccess(vm1);
        DependencyTracker.reportAccess(vm2);
        DependencyTracker.reportAccess(vm3);

        return widget.builder(context, vm1, vm2, vm3);
      });
    } catch (error) {
      accessed = DependencyTracker.captureAccessed();
      _reconcileSubscriptions(accessed);
      rethrow;
    }

    _reconcileSubscriptions(accessed);
    return built;
  }

  void _reconcileSubscriptions(Set<ObservableNode> accessed) {
    if (_currentNodes.length == accessed.length &&
        _currentNodes.containsAll(accessed)) {
      return;
    }

    final removed = _currentNodes.difference(accessed);

    if (removed.isNotEmpty) {
      for (final disposer in _disposers) {
        disposer();
      }
      _disposers.clear();

      for (final node in accessed) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    } else {
      final added = accessed.difference(_currentNodes);
      for (final node in added) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    }

    _currentNodes
      ..clear()
      ..addAll(accessed);
  }

  VoidCallback _createSubscription(ObservableNode node) {
    node.addListener(_onNodeChanged);
    return () => node.removeListener(_onNodeChanged);
  }
}

/// A widget that automatically binds based on Property that's been accessed
/// from three ViewModels accessed during its builder function.
///
/// This is the three-ViewModel variant of [BindViewModel]. Use when you need to
/// multiple properties at once from multiple ViewModels simultaneously.
///
/// Example:
/// ```dart
/// BindViewModel4<UserViewModel, SettingsViewModel, DataViewModel, CounterViewModel>(
///   builder: (context, user, settings, data, counter) {
///     return Column(
///       children: [
///         Text('User: ${user.name.value}'),
///         Text('Theme: ${settings.theme.value}'),
///         Text('Count: ${data.count.value}'),
///         Text('Counter: ${counter.value}'),
///       ],
///     );
///   },
/// )
/// ```
class BindViewModel4<
    TViewModel1 extends ObservableObject,
    TViewModel2 extends ObservableObject,
    TViewModel3 extends ObservableObject,
    TViewModel4 extends ObservableObject> extends StatefulWidget {
  /// The builder function that receives three resolved ViewModels.
  final Widget Function(
    BuildContext context,
    TViewModel1 vm1,
    TViewModel2 vm2,
    TViewModel3 vm3,
    TViewModel4 vm4,
  ) builder;

  const BindViewModel4({
    super.key,
    required this.builder,
  });

  @override
  State<BindViewModel4<TViewModel1, TViewModel2, TViewModel3, TViewModel4>>
      createState() => _BindViewModel4State<TViewModel1, TViewModel2,
          TViewModel3, TViewModel4>();
}

class _BindViewModel4State<
        TViewModel1 extends ObservableObject,
        TViewModel2 extends ObservableObject,
        TViewModel3 extends ObservableObject,
        TViewModel4 extends ObservableObject>
    extends State<
        BindViewModel4<TViewModel1, TViewModel2, TViewModel3, TViewModel4>> {
  final List<VoidCallback> _disposers = [];
  final Set<ObservableNode> _currentNodes = {};

  void _onNodeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _currentNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm1 = Fairy.of<TViewModel1>(context);
    final vm2 = Fairy.of<TViewModel2>(context);
    final vm3 = Fairy.of<TViewModel3>(context);
    final vm4 = Fairy.of<TViewModel4>(context);

    Widget built;
    Set<ObservableNode> accessed;

    try {
      (built, accessed) = DependencyTracker.track(() {
        // ✅ Always report ViewModels access
        DependencyTracker.reportAccess(vm1);
        DependencyTracker.reportAccess(vm2);
        DependencyTracker.reportAccess(vm3);
        DependencyTracker.reportAccess(vm4);

        return widget.builder(context, vm1, vm2, vm3, vm4);
      });
    } catch (error) {
      accessed = DependencyTracker.captureAccessed();
      _reconcileSubscriptions(accessed);
      rethrow;
    }

    _reconcileSubscriptions(accessed);
    return built;
  }

  void _reconcileSubscriptions(Set<ObservableNode> accessed) {
    if (_currentNodes.length == accessed.length &&
        _currentNodes.containsAll(accessed)) {
      return;
    }

    final removed = _currentNodes.difference(accessed);

    if (removed.isNotEmpty) {
      for (final disposer in _disposers) {
        disposer();
      }
      _disposers.clear();

      for (final node in accessed) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    } else {
      final added = accessed.difference(_currentNodes);
      for (final node in added) {
        final disposer = _createSubscription(node);
        _disposers.add(disposer);
      }
    }

    _currentNodes
      ..clear()
      ..addAll(accessed);
  }

  VoidCallback _createSubscription(ObservableNode node) {
    node.addListener(_onNodeChanged);
    return () => node.removeListener(_onNodeChanged);
  }
}
