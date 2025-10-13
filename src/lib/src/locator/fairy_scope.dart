import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/observable.dart';
import 'fairy_locator.dart';

/// Provides access to dependencies during ViewModel construction.
///
/// **IMPORTANT:** This locator is ONLY valid during FairyScope initialization.
/// Do not store references to it or use it outside the factory function.
///
/// This context is passed to factory functions in [FairyScope.viewModel] and
/// [FairyScope.viewModels], allowing ViewModels to resolve dependencies from:
/// - Global services registered in [FairyLocator]
/// - Parent scope ViewModels registered in ancestor [FairyScope] widgets
///
/// Example:
/// ```dart
/// FairyScope(
///   viewModel: (locator) => CounterViewModel(
///     apiService: locator.get<ApiService>(),        // From FairyLocator
///     appViewModel: locator.get<AppViewModel>(),    // From parent FairyScope
///   ),
///   child: CounterPage(),
/// )
/// ```
abstract class FairyScopeLocator {
  /// Resolves a dependency of type [T].
  ///
  /// Resolution order:
  /// 1. Parent [FairyScope] widgets (nearest first)
  /// 2. Global [FairyLocator] singleton/factory registrations
  ///
  /// Throws [StateError] if no dependency of type [T] is found.
  /// Throws [StateError] if called outside FairyScope initialization.
  T get<T extends Object>();
}

/// Data holder for managing scoped ViewModels within a [FairyScope].
///
/// This class maintains a local registry of ViewModels and tracks which ones
/// were created by the scope (and therefore should be disposed by it).
///
/// **Internal API:** This class is intended for internal use by FairyScope only.
/// Do not use it directly in application code.
@internal
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

/// Internal implementation of [FairyScopeLocator].
///
/// This class is sealed to prevent external instantiation and ensure
/// locator instances are only created during FairyScope initialization.
///
/// **Performance Optimization:** Uses hybrid flattening approach:
/// 1. Current scope checked directly (O(1), supports future lazy loading)
/// 2. Parent scopes flattened into single map (O(1) lookup instead of O(n) iteration)
/// 3. Pre-collected during construction to avoid repeated tree traversal
///
/// **Memory Safety:** Uses weak references in flattened map to prevent
/// retention of disposed parent scopes in edge cases.
class _FairyScopeLocatorImpl implements FairyScopeLocator {
  final FairyScopeData _currentScopeData;
  final Map<Type, WeakReference<ObservableObject>> _flattenedParents;
  bool _isValid = true;

  _FairyScopeLocatorImpl(
    this._currentScopeData,
    List<FairyScopeData> parentScopes,
  ) : _flattenedParents = _flattenParentScopes(parentScopes);

  /// Flattens parent scope registries into a single map for O(1) lookup.
  ///
  /// Parent scopes are processed from farthest to nearest, so nearest parents
  /// override farthest in case of type conflicts (which shouldn't happen in
  /// well-designed hierarchies, but this ensures correct behavior).
  ///
  /// Uses weak references to prevent memory leaks if parent scopes are disposed.
  static Map<Type, WeakReference<ObservableObject>> _flattenParentScopes(
    List<FairyScopeData> parentScopes,
  ) {
    final flattened = <Type, WeakReference<ObservableObject>>{};
    
    // Iterate from farthest to nearest (reversed order)
    // This ensures nearest parent wins in case of duplicate types
    for (final parentData in parentScopes.reversed) {
      for (final entry in parentData._registry.entries) {
        flattened[entry.key] = WeakReference<ObservableObject>(entry.value);
      }
    }
    
    return flattened;
  }

  /// Invalidates this locator after initialization is complete.
  void _invalidate() {
    _isValid = false;
  }

  @override
  T get<T extends Object>() {
    assert(_isValid, 'FairyScopeLocator used after invalidation');

    if (!_isValid) {
      throw StateError(
        'FairyScopeLocator can only be used during ViewModel initialization.\n'
        'Do not store references to the locator or use it outside the factory function.\n'
        '\n'
        'Valid usage:\n'
        '  FairyScope(\n'
        '    viewModel: (locator) => MyViewModel(\n'
        '      service: locator.get<MyService>(), // ✓ OK\n'
        '    ),\n'
        '  )\n'
        '\n'
        'Invalid usage:\n'
        '  class MyViewModel {\n'
        '    late final FairyScopeLocator _locator;\n'
        '    MyViewModel(FairyScopeLocator locator) {\n'
        '      _locator = locator; // ✗ DON\'T store it\n'
        '    }\n'
        '    void someMethod() {\n'
        '      _locator.get<Service>(); // ✗ Will throw\n'
        '    }\n'
        '  }',
      );
    }

    // HYBRID APPROACH for optimal performance:
    
    // 1. Always check current scope directly (O(1))
    //    This supports future lazy creation and sequential dependencies
    final currentResult = _currentScopeData._registry[T];
    if (currentResult != null) {
      return currentResult as T;
    }

    // 2. Check flattened parent scopes (O(1) instead of O(n) iteration)
    //    Uses weak references to prevent memory leaks
    final parentWeakRef = _flattenedParents[T];
    if (parentWeakRef != null) {
      final parentResult = parentWeakRef.target;
      if (parentResult != null) {
        return parentResult as T;
      }
      // Weak reference was garbage collected - fall through to next step
    }

    // 3. Fall back to global FairyLocator
    try {
      return FairyLocator.instance.get<T>();
    } catch (e) {
      throw StateError(
        'No dependency of type $T found in FairyScope hierarchy or FairyLocator.\n'
        'Make sure to:\n'
        '1. Register services with FairyLocator.instance.registerSingleton<$T>(...)\n'
        '2. Or provide ViewModels via parent FairyScope widgets',
      );
    }
  }
}

/// A widget that provides scoped dependency injection for ViewModels.
///
/// [FairyScope] creates a widget subtree where ViewModels are available to
/// descendants via [FairyScope.of] or through `Bind` and `Command` widgets.
///
/// **Key Features:**
/// - Scoped lifecycle: ViewModels are automatically disposed when the scope is removed
/// - Dependency injection: Factory functions receive [FairyScopeLocator] for resolving dependencies
/// - Hierarchical resolution: Access parent scope VMs and global services
/// - Memory-safe: Only disposes VMs it created (when [autoDispose] is true)
///
/// **Important:** This widget does NOT automatically register to [FairyLocator].
/// Scoped VMs remain local to the widget tree unless explicitly registered globally.
///
/// Example with single ViewModel:
/// ```dart
/// FairyScope(
///   viewModel: (locator) => CounterViewModel(
///     apiService: locator.get<ApiService>(),
///     appViewModel: locator.get<AppViewModel>(),
///   ),
///   child: CounterPage(),
/// )
/// ```
///
/// Example with multiple ViewModels:
/// ```dart
/// FairyScope(
///   viewModels: [
///     (locator) => UserViewModel(
///       authService: locator.get<AuthService>(),
///     ),
///     (locator) => SettingsViewModel(
///       storageService: locator.get<StorageService>(),
///       userViewModel: locator.get<UserViewModel>(), // From same scope
///     ),
///   ],
///   child: DashboardPage(),
/// )
/// ```
class FairyScope extends StatefulWidget {
  /// The widget subtree that can access scoped ViewModels.
  final Widget child;

  /// Factory function to create a single ViewModel.
  ///
  /// The factory receives a [FairyScopeLocator] to resolve dependencies from:
  /// - Global services in [FairyLocator]
  /// - Parent scope ViewModels
  ///
  /// **IMPORTANT:** Do not store the locator reference or use it outside
  /// the factory function. It is only valid during initialization.
  ///
  /// The created ViewModel will be owned and disposed by this scope.
  final ObservableObject Function(FairyScopeLocator locator)? viewModel;

  /// List of factory functions to create multiple ViewModels.
  ///
  /// Each factory receives a [FairyScopeLocator] to resolve dependencies.
  /// ViewModels are created in order, so later factories can depend on
  /// earlier ViewModels in the same scope.
  ///
  /// **IMPORTANT:** Do not store the locator reference or use it outside
  /// the factory functions. It is only valid during initialization.
  ///
  /// All created ViewModels will be owned and disposed by this scope.
  ///
  /// Example:
  /// ```dart
  /// FairyScope(
  ///   viewModels: [
  ///     (locator) => UserViewModel(),
  ///     (locator) => SettingsViewModel(
  ///       userViewModel: locator.get<UserViewModel>(), // Depends on first VM
  ///     ),
  ///   ],
  ///   child: MyApp(),
  /// )
  /// ```
  final List<ObservableObject Function(FairyScopeLocator locator)>? viewModels;

  /// Whether to automatically dispose ViewModels created by this scope.
  ///
  /// When `true` (default), ViewModels created via [viewModel] or [viewModels]
  /// are disposed when the scope is removed.
  ///
  /// When `false`, no automatic disposal occurs.
  final bool autoDispose;

  const FairyScope({
    super.key,
    required this.child,
    this.viewModel,
    this.viewModels,
    this.autoDispose = true,
  }) : assert(
          viewModel == null || viewModels == null,
          'Cannot use both viewModel and viewModels. Use one or the other.',
        );

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

    // Pre-collect parent scopes ONCE during initialization (performance optimization)
    // This avoids repeated tree traversal on every get<T>() call
    final List<FairyScopeData> parentScopes = [];
    context.visitAncestorElements((ancestor) {
      if (ancestor.widget is _FairyScopeInherited) {
        final scopeData = (ancestor.widget as _FairyScopeInherited).data;
        // Don't add the current scope (should not happen, but safety check)
        if (scopeData != _data) {
          parentScopes.add(scopeData);
        }
      }
      return true; // Continue visiting ancestors
    });

    // Create locator WITHOUT context reference (memory safety)
    // Parent scopes are pre-collected and stored as weak references
    final locator = _FairyScopeLocatorImpl(_data, parentScopes);

    try {
      // Register single ViewModel created via factory
      if (widget.viewModel != null) {
        final instance = widget.viewModel!(locator);
        _data.registerDynamic(instance, owned: widget.autoDispose);
      }

      // Register multiple ViewModels created via factories
      if (widget.viewModels != null) {
        for (final factory in widget.viewModels!) {
          final instance = factory(locator);
          _data.registerDynamic(instance, owned: widget.autoDispose);
        }
      }
    } finally {
      // Invalidate locator after initialization to prevent misuse
      locator._invalidate();
    }
  }

  @override
  void dispose() {
    // Always call dispose to clear registry and release references
    // This prevents memory leaks even when autoDispose is false
    _data.dispose();
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
