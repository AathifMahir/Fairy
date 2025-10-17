import 'package:fairy/src/core/observable_node.dart';
import 'package:flutter/foundation.dart';

/// Internal-only dependency tracker using stack-based sessions.
///
/// This class is NOT exported from the package and is an implementation detail
/// of the Bind.observer widget's automatic dependency tracking system.
///
/// Uses a stack-based approach (not Zone-based) for better performance,
/// exception safety, and hot reload stability.
@internal
class DependencyTracker {
  // Thread-local stack (Flutter is single-threaded, so static is safe)
  static final List<_TrackingSession> _stack = [];

  /// Gets whether there is an active tracking session.
  ///
  /// Used to optimize reportAccess() calls - if no session is active,
  /// reportAccess can return immediately without any work.
  static bool get isTracking => _stack.isNotEmpty;

  /// Gets the current tracking session (if any).
  static _TrackingSession? get _currentSession {
    return _stack.isEmpty ? null : _stack.last;
  }

  /// Reports that an ObservableNode was accessed during the current session.
  ///
  /// If no tracking session is active, this is a no-op (returns immediately).
  /// This allows getters to call reportAccess() unconditionally without overhead
  /// when not being tracked.
  static void reportAccess(ObservableNode node) {
    // ✅ Early return optimization - no work if not tracking
    if (!isTracking) return;

    _currentSession?._accessed.add(node);
  }

  /// Runs a function within a tracking session.
  ///
  /// Returns the function result and the set of ObservableNodes accessed
  /// during execution. If an exception occurs, partial tracking is preserved
  /// and the exception is re-thrown after cleanup.
  ///
  /// Example:
  /// ```dart
  /// final (widget, accessed) = DependencyTracker.track(() {
  ///   return builder(context, viewModel);
  /// });
  /// ```
  static (T result, Set<ObservableNode> accessed) track<T>(T Function() fn) {
    final session = _TrackingSession();
    _stack.add(session);

    try {
      final result = fn();
      return (result, session._accessed);
    } catch (error) {
      // ✅ CRITICAL: Partial tracking is still valid even on exception
      // This ensures subscriptions are updated correctly before re-throwing
      rethrow;
    } finally {
      // ✅ CRITICAL: Always pop session, even on exception
      final popped = _stack.removeLast();

      // Debug assertion to catch stack corruption early
      assert(
        identical(popped, session),
        'DependencyTracker session stack corrupted. Expected $session but got $popped.',
      );
    }
  }

  /// Returns the currently accessed nodes (for exception handling).
  ///
  /// Used by BindObserver to capture partial tracking when an exception
  /// occurs during build, allowing proper subscription reconciliation
  /// before re-throwing.
  static Set<ObservableNode> captureAccessed() {
    return _currentSession?._accessed ?? const {};
  }
}

/// Private tracking session that collects accessed ObservableNodes.
///
/// Each BindObserver build creates its own session. Sessions are isolated
/// via the stack, so nested builds don't interfere with each other.
class _TrackingSession {
  final Set<ObservableNode> _accessed = {};
}
