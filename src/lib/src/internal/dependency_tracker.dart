import 'package:fairy/src/core/observable_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Internal dependency tracker using stack-based sessions with
/// InheritedWidget fallback for lazy builders.
///
/// NOT exported - implementation detail of Bind.viewModel's automatic tracking.
///
/// Stack-based (not Zone-based) for performance and stability.
/// InheritedWidget fallback enables deferred callbacks (ListView.builder)
/// to report property accesses.
@internal
class DependencyTracker {
  // Stack of active tracking sessions (Flutter is single-threaded)
  static final List<_TrackingSession> _stack = [];

  // BuildContext for lazy builder tracking fallback
  static BuildContext? _currentContext;

  /// Sets BuildContext for lazy builder tracking. Internal use only.
  static void setCurrentContext(BuildContext? context) {
    _currentContext = context;
  }

  /// Whether there is an active tracking session.
  /// Optimizes reportAccess() by allowing early returns.
  static bool get isTracking => _stack.isNotEmpty;

  /// Reports ObservableNode access during current session.
  ///
  /// No-op if no session is active. Supports two modes:
  /// 1. Stack-based (primary): Synchronous build execution
  /// 2. Context-based (fallback): Deferred callbacks via InheritedWidget
  static void reportAccess(ObservableNode node) {
    // Early exit if no tracking session active (optimization)
    if (_stack.isEmpty && _currentContext == null) {
      return;
    }

    // Stack-based session (primary - synchronous build)
    if (_stack.isNotEmpty) {
      _stack.last._accessed.add(node);
      return;
    }

    // Context-based fallback (deferred callbacks like itemBuilder)
    final context = _currentContext;
    if (context != null) {
      final session = _TrackingContextWidget._maybeOf(context);
      session?._accessed.add(node);
    }
  }

  /// Runs function within tracking session.
  ///
  /// Returns: (result, accessed nodes, optional session for deferred tracking).
  /// Exceptions preserve partial tracking before re-throwing.
  ///
  /// When [wrapWithContext] is true, wraps result with InheritedWidget
  /// to enable lazy builder callbacks to report accesses.
  static (T result, Set<ObservableNode> accessed, _TrackingSession? session)
      track<T>(
    T Function() fn, {
    bool wrapWithContext = false,
  }) {
    final session = _TrackingSession();
    _stack.add(session);

    try {
      final result = fn();

      // Wrap with InheritedWidget to enable deferred callback tracking
      if (wrapWithContext && result is Widget) {
        return (
          _TrackingContextWidget(
            session: session,
            child: result,
          ) as T,
          Set.from(session._accessed), // Snapshot for comparison
          session // For checking deferred accesses
        );
      }

      return (result, session._accessed, null);
    } catch (error) {
      // CRITICAL: Preserve partial tracking before re-throwing
      rethrow;
    } finally {
      // CRITICAL: Always pop session, even on exception
      final popped = _stack.removeLast();

      assert(
        identical(popped, session),
        'DependencyTracker stack corrupted',
      );
    }
  }

  /// Returns currently accessed nodes for exception handling.
  /// Used by BindObserver for partial tracking on build exceptions.
  static Set<ObservableNode> captureAccessed() {
    return _stack.isEmpty ? const {} : _stack.last._accessed;
  }
}

/// Tracking session collecting accessed ObservableNodes.
/// Stack-isolated - nested builds don't interfere.
class _TrackingSession {
  final Set<ObservableNode> _accessed = {};

  /// Snapshot of accessed nodes for deferred access comparison.
  Set<ObservableNode> getAccessedSnapshot() => Set.from(_accessed);
}

/// InheritedWidget propagating tracking session down the tree.
/// Enables deferred callbacks (itemBuilder) to report accesses.
/// Phase 2.2 optimization: Captures BuildContext directly in initState.
/// Internal use only.
class _TrackingContextWidget extends InheritedWidget {
  final _TrackingSession session;

  const _TrackingContextWidget({
    required this.session,
    required super.child,
  });

  /// Retrieves nearest tracking session from widget tree.
  /// Used by reportAccess() as fallback for deferred callbacks.
  static _TrackingSession? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TrackingContextWidget>()
        ?.session;
  }

  @override
  bool updateShouldNotify(_TrackingContextWidget oldWidget) {
    return false; // Session identity never changes
  }

  @override
  InheritedElement createElement() {
    return _TrackingContextElement(this);
  }
}

/// Custom Element that captures BuildContext on mount.
/// Phase 2.2 optimization: Eliminates _ContextSetter StatefulWidget overhead.
class _TrackingContextElement extends InheritedElement {
  _TrackingContextElement(_TrackingContextWidget super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    // Capture context immediately after mounting
    DependencyTracker.setCurrentContext(this);
  }

  @override
  void unmount() {
    // Clear context before unmounting
    DependencyTracker.setCurrentContext(null);
    super.unmount();
  }
}
