import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:fairy/src/internal/fairy_scope_locator.dart';
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
  static FairyScopeData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FairyScopeInherited>()?.data;

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
    final locator = FairyScopeLocatorImpl(_data, parentScopes);

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
      locator.invalidate();
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
