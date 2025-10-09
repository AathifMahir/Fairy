import 'package:flutter/foundation.dart';

/// Base class for ViewModels that provides change notification capabilities.
///
/// Extends [ChangeNotifier] to enable reactive updates when model state changes.
/// Use this as a base for all ViewModels in your application.
///
/// The raw [ChangeNotifier] API is hidden to provide a cleaner MVVM-style interface:
/// - Use [onPropertyChanged] instead of [notifyListeners]
/// - Use [propertyChanged] instead of [addListener]
///
/// Example:
/// ```dart
/// class CounterViewModel extends ObservableObject {
///   int _count = 0;
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     onPropertyChanged(); // Notify listeners of the change
///   }
/// }
/// ```
abstract class ObservableObject extends ChangeNotifier {
  final List<ChangeNotifier> _children = [];

  /// Internal method to register a child ChangeNotifier for auto-disposal.
  /// 
  /// This is called automatically by ObservableProperty, ComputedProperty, and
  /// command types when a parent is provided during construction.
  /// 
  /// Note: This is intentionally public (not @protected) to allow registration
  /// from command classes that are not subclasses of ObservableObject.
  void registerChild<T extends ChangeNotifier>(T notifier) {
    // Skip nested ObservableObjects (they manage their own disposal)
    if (notifier is ObservableObject) {
      return;
    }
    
    _children.add(notifier);
  }

  // ========================================================================
  // HIDDEN ChangeNotifier API (marked @protected for internal framework use)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();
  
  // ========================================================================
  // PUBLIC FAIRY API (MVVM-style naming)
  // ========================================================================
  
  /// Notifies all listeners that one or more properties have changed.
  ///
  /// Call this method after changing properties to trigger UI rebuilds.
  /// This is the MVVM-style equivalent of [notifyListeners].
  ///
  /// Example:
  /// ```dart
  /// void updateUser(String name, int age) {
  ///   _name = name;
  ///   _age = age;
  ///   onPropertyChanged(); // Single notification for batch changes
  /// }
  /// ```
  @protected
  void onPropertyChanged() => notifyListeners();

  /// Listens to property changes on this ViewModel.
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final dispose = viewModel.propertyChanged(() {
  ///   print('ViewModel changed!');
  /// });
  /// 
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback propertyChanged(VoidCallback listener) {
    super.addListener(listener);
    return () => super.removeListener(listener);
  }

  /// Helper method to set a property with automatic change detection.
  ///
  /// Compares [oldValue] with [newValue] and only calls [assign] and
  /// [onPropertyChanged] if they differ.
  ///
  /// Returns `true` if the value changed and listeners were notified.
  ///
  /// Example:
  /// ```dart
  /// class MyViewModel extends ObservableObject {
  ///   String _name = '';
  ///   String get name => _name;
  ///   set name(String value) => setProperty(_name, value, () => _name = value);
  /// }
  /// ```
  @protected
  bool setProperty<T>(T oldValue, T newValue, void Function() assign) {
    if (oldValue != newValue) {
      assign();
      onPropertyChanged();
      return true;
    }
    return false;
  }

  /// Override this method to perform cleanup when the ViewModel is disposed.
  ///
  /// Always call `super.dispose()` at the end of your override.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   // Clean up resources
  ///   _subscription.cancel();
  ///   super.dispose();
  /// }
  /// ```
  @override
  void dispose() {
    // Dispose children in reverse order to avoid notifying already-disposed dependents
    for (final n in _children.reversed) {
      n.dispose();
    }
    _children.clear();
    super.dispose();
  }
}

/// A strongly-typed, reactive property wrapper that notifies listeners when its value changes.
///
/// Use [ObservableProperty] to create two-way bindable properties in ViewModels.
/// The generic type [T] ensures type safety throughout the binding chain.
///
/// This is the primary primitive for two-way binding detection in the Fairy framework.
/// When used with the `Bind` widget, it automatically enables two-way data binding.
///
/// Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   late final ObservableProperty<String> userName;
///   late final ObservableProperty<int> age;
///
///   UserViewModel() {
///     userName = ObservableProperty<String>('', parent: this);
///     age = ObservableProperty<int>(0, parent: this);
///   }
///
///   void updateUserName(String newName) {
///     userName.value = newName; // Automatically notifies listeners
///   }
///
///   // Properties auto-disposed by super.dispose()
/// }
/// ```
///
/// **Important:** Always use `final` for [ObservableProperty] fields and return
/// stable references from selectors. Never create new instances in getters.
class ObservableProperty<T> extends ChangeNotifier {
  T _value;

  /// Creates an [ObservableProperty] with an initial value.
  /// 
  /// If [parent] is provided, this property will be automatically disposed
  /// when the parent is disposed. If null, you must manually call dispose().
  ObservableProperty(this._value, {ObservableObject? parent}) {
    if (parent != null) {
      parent.registerChild(this);
    }
  }

  // ========================================================================
  // HIDDEN ChangeNotifier API (internal use only)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();
  
  // ========================================================================
  // PUBLIC FAIRY API
  // ========================================================================

  /// Gets the current value.
  T get value => _value;

  /// Sets a new value and notifies listeners only if the value differs.
  ///
  /// Uses `!=` for comparison, so ensure your types have proper equality.
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      super.notifyListeners();
    }
  }

  /// Updates the value using a function and notifies listeners if changed.
  ///
  /// This is useful for functional-style updates or when you need to
  /// modify the value based on its current state.
  ///
  /// Example:
  /// ```dart
  /// final counter = ObservableProperty<int>(0);
  /// counter.update((current) => current + 1);
  /// ```
  void update(T Function(T current) updater) {
    final newValue = updater(_value);
    if (newValue != _value) {
      _value = newValue;
      super.notifyListeners();
    }
  }

  /// Listens to value changes on this property.
  ///
  /// Returns a disposal function that removes the listener when called.
  ///
  /// Example:
  /// ```dart
  /// final dispose = userName.listen(() {
  ///   print('Name changed to: ${userName.value}');
  /// });
  /// // Later:
  /// dispose();
  /// ```
  VoidCallback propertyChanged(VoidCallback listener) {
    super.addListener(listener);
    return () => super.removeListener(listener);
  }
}

/// A read-only property that automatically recomputes when dependencies change.
///
/// [ComputedProperty] is useful for derived values that depend on other
/// observable properties. It caches the computed result and only recalculates
/// when one of its dependencies notifies listeners.
///
/// Example:
/// ```dart
/// class ShoppingCartViewModel extends ObservableObject {
///   late final ObservableProperty<List<Item>> items;
///   late final ComputedProperty<double> totalPrice;
///
///   ShoppingCartViewModel() {
///     items = ObservableProperty<List<Item>>([], parent: this);
///     
///     totalPrice = ComputedProperty<double>(
///       () => items.value.fold(0.0, (sum, item) => sum + item.price),
///       [items],
///       parent: this,
///     );
///   }
///
///   // Properties and computed properties auto-disposed by super.dispose()
/// }
/// ```
class ComputedProperty<T> extends ChangeNotifier {

  /// Creates a computed property with a computation function and dependencies.
  ///
  /// The [compute] function is called to calculate the value.
  /// The [dependencies] list contains all [Listenable] objects that this
  /// computed property depends on. When any dependency notifies, the cached
  /// value is invalidated and recalculated.
  /// 
  /// If [parent] is provided, this property will be automatically disposed
  /// when the parent is disposed. If null, you must manually call dispose().
  ComputedProperty(this._compute, this._dependencies, {ObservableObject? parent}) {
    if (parent != null) {
      parent.registerChild(this);
    }
    
    for (final dep in _dependencies) {
      dep.addListener(_onDependencyChanged);
    }
    // Initialize cache
    _cachedValue = _compute();
  }
  final T Function() _compute;
  final List<Listenable> _dependencies;
  T? _cachedValue;
  bool _isDisposed = false;


    // ========================================================================
  // HIDDEN ChangeNotifier API (internal use only)
  // ========================================================================
  
  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);
  
  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);
  
  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Gets the current computed value.
  ///
  /// Returns the cached value if available, otherwise recomputes.
  T get value {
    if (_cachedValue == null && !_isDisposed) {
      _cachedValue = _compute();
    }
    return _cachedValue as T;
  }

  void _onDependencyChanged() {
    if (_isDisposed) {
      return;
    }
    final newValue = _compute();
    if (_cachedValue != newValue) {
      _cachedValue = newValue;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
    super.dispose();
  }
}
