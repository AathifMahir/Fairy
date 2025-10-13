import 'package:flutter/foundation.dart';

typedef VoidListener = void Function();

abstract class ObservableNode {
  final List<VoidListener> _listeners = [];

  bool get hasListeners => _listeners.isNotEmpty;

  /// Register a listener
  void addListener(VoidListener listener) {
    _listeners.add(listener);
  }

  /// Unregister a listener
  void removeListener(VoidListener listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  @protected
  void notifyListeners() {
    for (final l in List<VoidListener>.from(_listeners)) {
      l();
    }
  }

  /// Optional: clear all listeners (manual cleanup if needed), if not Dart GC will handle it
  void dispose() => _listeners.clear();

}