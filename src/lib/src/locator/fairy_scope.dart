import 'package:flutter/widgets.dart';
import '../core/observable.dart';

/// Data holder for managing scoped ViewModels within a [FairyScope].
///
/// This class maintains a local registry of ViewModels and tracks which ones
/// were created by the scope (and therefore should be disposed by it).
class FairyScopeData {
  final Map<Type, ObservableObject> _registry = {};
  final Set<Type> _ownedTypes = {};

  /// Registers a ViewModel instance of type [T].
  ///
  /// [owned] indicates whether this scope created the instance and is
  /// responsible for disposing it.
  void register<T extends ObservableObject>(T instance, {bool owned = false}) {
    _registry[T] = instance;
    if (owned) {
      _ownedTypes.add(T);
    }
  }

  /// Registers a ViewModel instance using its runtime type.
  ///
  /// This is useful when iterating over a list of ViewModels where the
  /// compile-time type is not available.
  void registerDynamic(ObservableObject instance, {bool owned = false}) {
    final type = instance.runtimeType;
    _registry[type] = instance;
    if (owned) {
      _ownedTypes.add(type);
    }
  }

  /// Retrieves a ViewModel of type [T].
  ///
  /// Throws [StateError] if no ViewModel of type [T] is registered.
  T get<T extends ObservableObject>() {
    if (!_registry.containsKey(T)) {
      throw StateError('No ViewModel of type $T found in FairyScope');
    }
    return _registry[T] as T;
  }

  /// Checks if a ViewModel of type [T] is registered.
  bool contains<T extends ObservableObject>() => _registry.containsKey(T);

  /// Disposes all ViewModels that this scope owns.
  ///
  /// Only disposes ViewModels that were created by this scope (marked as owned).
  void dispose() {
    for (final type in _ownedTypes) {
      final vm = _registry[type];
      if (vm != null) {
        vm.dispose();
      }
    }
    _ownedTypes.clear();
    _registry.clear();
  }
}

/// A widget that provides scoped dependency injection for ViewModels.
///
/// [FairyScope] creates a widget subtree where ViewModels are available to
/// descendants via [FairyScope.of] or through `Bind` and `Command` widgets.
///
/// **Key Features:**
/// - Scoped lifecycle: ViewModels are automatically disposed when the scope is removed
/// - Flexible registration: Pass pre-created VMs or use `create` factory
/// - Memory-safe: Only disposes VMs it created (when [autoDispose] is true)
///
/// **Important:** This widget does NOT automatically register to [FairyLocator].
/// Scoped VMs remain local to the widget tree unless explicitly registered globally.
///
/// Example:
/// ```dart
/// FairyScope(
///   create: () => CounterViewModel(),
///   child: MaterialApp(
///     home: CounterPage(),
///   ),
/// )
/// ```
///
/// Multiple ViewModels:
/// ```dart
/// FairyScope(
///   viewModels: [
///     UserViewModel(),
///     SettingsViewModel(),
///   ],
///   child: MyWidget(),
/// )
/// ```
class FairyScope extends StatefulWidget {
  /// The widget subtree that can access scoped ViewModels.
  final Widget child;

  /// Optional list of pre-created ViewModels to register.
  ///
  /// These ViewModels will NOT be disposed by the scope (unless you set
  /// [autoDispose] to false and manage disposal externally).
  final List<ObservableObject>? viewModels;

  /// Factory function to create a single ViewModel.
  ///
  /// The created ViewModel will be owned and disposed by this scope.
  final ObservableObject Function()? create;

  /// Whether to automatically dispose ViewModels created by this scope.
  ///
  /// When `true` (default), ViewModels created via [create] are disposed
  /// when the scope is removed. ViewModels passed via [viewModels] are
  /// NOT disposed by default (assumed to be managed externally).
  ///
  /// When `false`, no automatic disposal occurs.
  final bool autoDispose;

  const FairyScope({
    super.key,
    required this.child,
    this.viewModels,
    this.create,
    this.autoDispose = true,
  });

  /// Retrieves the [FairyScopeData] from the nearest [FairyScope] ancestor.
  ///
  /// Returns `null` if no [FairyScope] is found in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final scopeData = FairyScope.of(context);
  /// if (scopeData != null && scopeData.contains<MyViewModel>()) {
  ///   final vm = scopeData.get<MyViewModel>();
  /// }
  /// ```
  static FairyScopeData? of(BuildContext context) => context
        .dependOnInheritedWidgetOfExactType<_FairyScopeInherited>()
        ?.data;

  @override
  State<FairyScope> createState() => _FairyScopeState();
}

class _FairyScopeState extends State<FairyScope> {
  late final FairyScopeData _data;

  @override
  void initState() {
    super.initState();
    _data = FairyScopeData();

    // Register ViewModel created via factory
    if (widget.create != null) {
      final instance = widget.create!();
      _data.registerDynamic(instance, owned: widget.autoDispose);
    }

    // Register pre-created ViewModels
    if (widget.viewModels != null) {
      for (final vm in widget.viewModels!) {
        _data.registerDynamic(vm, owned: false); // Not owned by scope
      }
    }
  }

  @override
  void dispose() {
    if (widget.autoDispose) {
      _data.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FairyScopeInherited(
      data: _data,
      child: widget.child,
    );
}

/// InheritedWidget that provides [FairyScopeData] to the widget tree.
class _FairyScopeInherited extends InheritedWidget {

  const _FairyScopeInherited({
    required this.data,
    required super.child,
  });
  final FairyScopeData data;

  @override
  bool updateShouldNotify(_FairyScopeInherited old) => false;
}
