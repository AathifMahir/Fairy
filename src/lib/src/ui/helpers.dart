import 'package:flutter/widgets.dart';

/// Helper utilities for UI binding to prevent common pitfalls.
///
/// These helpers solve memory leaks and performance issues that can occur
/// when binding ViewModels to UI widgets.

/// Cache for TextEditingControllers to prevent recreation on rebuilds.
///
/// **Problem:** Creating a new [TextEditingController] on every build causes
/// the cursor to jump to the end and loses selection state.
///
/// **Solution:** Use this cache to reuse controllers based on a stable key.
///
/// Example:
/// ```dart
/// Bind<MyViewModel, String>(
///   selector: (vm) => vm.userName,
///   builder: (context, value, update) {
///     final controller = TextControllerCache.of(context).get(
///       'userName',
///       value,
///       update,
///     );
///     return TextField(controller: controller);
///   },
/// )
/// ```
class TextControllerCache {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, void Function(String)?> _callbacks = {};

  /// Gets or creates a [TextEditingController] for the given key.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this controller
  /// - [value]: Current text value
  /// - [onChanged]: Optional callback when text changes (for two-way binding)
  TextEditingController get(
    String key,
    String value, [
    void Function(String)? onChanged,
  ]) {
    // Check if controller exists
    if (_controllers.containsKey(key)) {
      final controller = _controllers[key]!;

      // Update value if it changed externally (from ViewModel)
      if (controller.text != value) {
        final selection = controller.selection;
        controller.text = value;
        // Restore selection if possible
        if (selection.isValid) {
          controller.selection = selection;
        }
      }

      // Update callback if it changed
      if (_callbacks[key] != onChanged) {
        _callbacks[key] = onChanged;
      }

      return controller;
    }

    // Create new controller
    final controller = TextEditingController(text: value);
    _controllers[key] = controller;
    _callbacks[key] = onChanged;

    // Add listener for text changes
    if (onChanged != null) {
      controller.addListener(() {
        final callback = _callbacks[key];
        if (callback != null) {
          callback(controller.text);
        }
      });
    }

    return controller;
  }

  /// Disposes all cached controllers.
  ///
  /// Call this in your widget's dispose method if you're managing
  /// the cache manually.
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _callbacks.clear();
  }

  /// Gets the cache from the nearest [TextControllerCacheProvider].
  static TextControllerCache of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<TextControllerCacheProvider>();
    if (provider == null) {
      throw StateError(
        'No TextControllerCacheProvider found in widget tree. '
        'Wrap your widget with TextControllerCacheProvider.',
      );
    }
    return provider.cache;
  }
}

/// Provides a [TextControllerCache] to the widget tree.
///
/// Place this high in your widget tree (e.g., around each page/screen)
/// to enable TextEditingController caching.
///
/// Example:
/// ```dart
/// class MyPage extends StatefulWidget {
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
///
/// class _MyPageState extends State<MyPage> {
///   final _controllerCache = TextControllerCache();
///
///   @override
///   void dispose() {
///     _controllerCache.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextControllerCacheProvider(
///       cache: _controllerCache,
///       child: MyForm(),
///     );
///   }
/// }
/// ```
class TextControllerCacheProvider extends InheritedWidget {

  const TextControllerCacheProvider({
    required this.cache, required super.child, super.key,
  });
  final TextControllerCache cache;

  @override
  bool updateShouldNotify(TextControllerCacheProvider old) => cache != old.cache;
}

/// Extension on BuildContext for convenient TextEditingController creation.
extension TextControllerExt on BuildContext {
  /// Creates or retrieves a cached TextEditingController.
  ///
  /// Shorthand for `TextControllerCache.of(context).get(...)`.
  ///
  /// Example:
  /// ```dart
  /// final controller = context.textController('userName', value, update);
  /// ```
  TextEditingController textController(
    String key,
    String value, [
    void Function(String)? onChanged,
  ]) => TextControllerCache.of(this).get(key, value, onChanged);
}
