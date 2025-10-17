import 'package:flutter/foundation.dart';

/// Mixin for objects that need lifecycle management.
///
/// Provides a standard [isDisposed] flag to prevent operations on
/// disposed objects.
mixin Disposable {
  bool _isDisposed = false;

  /// Whether this object has been disposed.
  bool get isDisposed => _isDisposed;

  /// Throws if this object has been disposed.
  ///
  /// Use at the beginning of methods to prevent operations on disposed objects:
  /// ```dart
  /// void doSomething() {
  ///   throwIfDisposed();
  ///   // ... implementation
  /// }
  /// ```
  @protected
  void throwIfDisposed() {
    if (_isDisposed) {
      throw StateError(
        'Cannot perform operation on disposed $runtimeType',
      );
    }
  }

  /// Marks this object as disposed.
  /// used by subclasses in their [dispose] implementations.
  @protected
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
  }

}

/// Helper for managing multiple disposables as a group.
///
/// Useful when a ViewModel owns multiple resources that need disposal.
///
/// Example:
/// ```dart
/// class MyViewModel extends ObservableObject {
///   final _disposables = DisposableBag();
///
///   MyViewModel() {
///     _disposables.add(_subscription);
///     _disposables.add(_timer);
///   }
///
///   @override
///   void dispose() {
///     _disposables.dispose();
///     super.dispose();
///   }
/// }
/// ```
class DisposableBag {
  final List<VoidCallback> _disposables = [];

  /// Adds a dispose callback to the bag.
  void add(VoidCallback dispose) {
    _disposables.add(dispose);
  }

  /// Disposes all registered resources.
  void dispose() {
    for (final disposable in _disposables) {
      try {
        disposable();
      // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        // Log error but continue disposing other resources
        debugPrint('Error disposing resource: $e');
      }
    }
    _disposables.clear();
  }

  /// Clears all dispose callbacks without calling them.
  void clear() {
    _disposables.clear();
  }
}