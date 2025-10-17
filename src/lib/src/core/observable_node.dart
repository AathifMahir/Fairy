import 'package:flutter/foundation.dart';

typedef VoidListener = void Function();

abstract class ObservableNode {
  final List<VoidListener> _listeners = [];

  bool get hasListeners => _listeners.isNotEmpty;

  /// Register a listener
  ///
  /// Unlike some implementations, this allows the same listener to be
  /// registered multiple times, matching Flutter's ChangeNotifier behavior.
  /// Each registration will result in a separate call to the listener when
  /// notifyListeners() is invoked.
  void addListener(VoidListener listener) {
    _listeners.add(listener);
  }

  /// Unregister a listener
  ///
  /// If the same listener was registered multiple times, this removes only
  /// the first occurrence, matching Flutter's ChangeNotifier behavior.
  void removeListener(VoidListener listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  @protected
  void notifyListeners() {
    final snapshot = List<VoidListener>.from(_listeners);

    for (final listener in snapshot) {
      try {
        listener();
      } catch (error, stackTrace) {
        // Report errors without stopping other listeners
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'fairy',
          context: ErrorDescription(
            'while notifying listeners for $runtimeType',
          ),
        ));
      }
    }
  }

  /// Clears all listeners. Called during disposal.
  @protected
  void clearListeners() => _listeners.clear();

  /// Optional: clear all listeners (manual cleanup if needed), if not Dart GC will handle it
  @mustCallSuper
  void dispose() => _listeners.clear();
}
