import 'package:fairy/src/core/observable_node.dart';
import 'package:fairy/src/internal/dependency_tracker.dart';
import 'package:fairy/src/utils/equals.dart';
import 'package:fairy/src/utils/lifecycle.dart';
import 'package:flutter/foundation.dart';

/// Base class for ViewModels that provides change notification capabilities.
///
/// Extends [ObservableNode] to enable reactive updates when model state changes.
/// Use this as a base for all ViewModels in your application.
///
/// The raw [ObservableNode] API is hidden to provide a cleaner MVVM-style interface:
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
abstract class ObservableObject extends ObservableNode with Disposable {

  // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
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
  void onPropertyChanged(){
    throwIfDisposed();
    notifyListeners();
  }

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
    throwIfDisposed();
    addListener(listener);
    return () => removeListener(listener);
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
    throwIfDisposed();
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
    clearListeners();
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
/// **Deep Equality for Collections:**
/// 
/// By default, [ObservableProperty] uses deep equality for collections ([List], [Map], [Set]).
/// This prevents unnecessary rebuilds when setting "equivalent" collections:
///
/// ```dart
/// final tags = ObservableProperty<List<String>>(['admin', 'user']);
/// 
/// // Without deep equality: new object → rebuild (even though contents are identical)
/// // With deep equality: same contents → no rebuild (optimized!)
/// tags.value = ['admin', 'user'];
/// ```
///
/// You can disable deep equality if needed (e.g., for performance with large collections):
///
/// ```dart
/// // Disable deep equality (use reference equality only)
/// final items = ObservableProperty<List<Item>>([], deepEquality: false);
/// ```
///
/// **For custom types with collections:** Override the `==` operator on your model class:
///
/// ```dart
/// class User {
///   final String id;
///   final List<String> tags;
///   
///   @override
///   bool operator ==(Object other) =>
///     identical(this, other) ||
///     other is User && id == other.id && listEquals(tags, other.tags);
///   
///   @override
///   int get hashCode => id.hashCode ^ tags.hashCode;
/// }
/// ```
///
/// **Important:** Always use `final` for [ObservableProperty] fields and return
/// stable references from selectors. Never create new instances in getters.
class ObservableProperty<T> extends ObservableNode {
  T _value;
  final bool Function(T? a, T? b)? _deepEquals;

  /// Creates an [ObservableProperty] with an initial value.
  ///
  /// **Parameters:**
  /// - [initialValue]: The initial value for this property
  /// - [deepEquality]: Whether to use deep equality for collections ([List], [Map], [Set]).
  ///   Defaults to `true`. When enabled, collections are compared by contents rather than reference.
  ///
  /// **Examples:**
  ///
  /// ```dart
  /// // Basic usage with automatic deep equality for lists
  /// final tags = ObservableProperty<List<String>>(['admin']);
  ///
  /// // Disable deep equality for performance with large collections
  /// final largeList = ObservableProperty<List<Item>>([], deepEquality: false);
  /// ```
  ObservableProperty(
    this._value, {
    bool deepEquality = true,
  }) : _deepEquals = deepEquality ? Equals.deepEquals<T>() : null;

  // ========================================================================
  // HIDDEN ObservableNode API (internal use only)
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

  /// Gets the current value and reports access for automatic tracking.
  /// 
  /// When accessed within a Bind.observer builder, this property will be
  /// automatically subscribed to for rebuilds.
  T get value {
    // Report access for dependency tracking (no-op if not tracking)
    DependencyTracker.reportAccess(this);
    return _value;
  }

  /// Sets a new value and notifies listeners only if the value differs.
  ///
  /// Uses deep equality for collections if [deepEquality] is enabled (default),
  /// otherwise uses `==` comparison.
  set value(T newValue) {
    final isEqual = _deepEquals?.call(_value, newValue) ?? (_value == newValue);
    if (!isEqual) {
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
    final isEqual = _deepEquals?.call(_value, newValue) ?? (_value == newValue);
    if (!isEqual) {
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

/// A read-only, reactive property that automatically recomputes when dependencies change.
///
/// [ComputedProperty] eliminates manual synchronization by automatically deriving values
/// from other observable properties. It's cached, efficient, and makes ViewModels cleaner.
///
/// **Key Benefits:**
/// - Zero maintenance - no manual listener setup or cleanup
/// - Automatic caching - only recomputes when dependencies actually change
/// - Composable - can depend on other computed properties
/// - Type-safe with compile-time safety
/// - Auto-disposal prevents memory leaks
///
/// **Basic Usage:**
/// ```dart
/// class UserViewModel extends ObservableObject {
///   final firstName = ObservableProperty<String>('John');
///   final lastName = ObservableProperty<String>('Doe');
///   
///   // Automatically updates when firstName or lastName changes
///   late final fullName = ComputedProperty<String>(
///     () => '${firstName.value} ${lastName.value}',
///     [firstName, lastName],
///   );
/// }
/// ```
///
/// **Chained Computations (Shopping Cart):**
/// ```dart
/// late final subtotal = ComputedProperty<double>(
///   () => items.value.fold(0.0, (sum, item) => sum + item.price),
///   [items],
/// );
/// 
/// late final tax = ComputedProperty<double>(
///   () => subtotal.value * taxRate.value,
///   [subtotal, taxRate], // Depends on another computed property
/// );
/// 
/// late final total = ComputedProperty<double>(
///   () => subtotal.value + tax.value,
///   [subtotal, tax],
/// );
/// ```
///
/// **Form Validation:**
/// ```dart
/// late final isEmailValid = ComputedProperty<bool>(
///   () => email.value.contains('@') && email.value.length > 5,
///   [email],
/// );
/// 
/// late final canSubmit = ComputedProperty<bool>(
///   () => isEmailValid.value && isPasswordValid.value,
///   [isEmailValid, isPasswordValid],
/// );
/// 
/// late final submitCommand = RelayCommand(
///   _submit,
///   canExecute: () => canSubmit.value,
/// );
/// ```
///
/// **How It Works:**
/// 1. Registers listeners on all dependencies during construction
/// 2. Caches the computed value
/// 3. Recomputes when any dependency notifies
/// 4. Notifies own listeners only if value actually changed
/// 5. Auto-disposes all listeners with parent ViewModel
///
/// See the [README](https://pub.dev/packages/fairy#computedproperty) for more examples.
class ComputedProperty<T> extends ObservableNode {

  /// Creates a computed property with a computation function and dependencies.
  ///
  /// The [_compute] function calculates the derived value and should only depend on
  /// the provided [_dependencies]. When any dependency changes, the value is automatically
  /// recomputed. Always use `late final` for automatic disposal.
  ///
  /// Example:
  /// ```dart
  /// late final fullName = ComputedProperty<String>(
  ///   () => '${firstName.value} ${lastName.value}',
  ///   [firstName, lastName],
  /// );
  /// ```
  ComputedProperty(this._compute, this._dependencies) {
    for (final dep in _dependencies) {
      dep.addListener(_onDependencyChanged);
    }
    // Initialize cache
    _cachedValue = _compute();
  }
  final T Function() _compute;
  final List<ObservableNode> _dependencies;
  T? _cachedValue;
  bool _isDisposed = false;


    // ========================================================================
  // HIDDEN ObservableNode API (internal use only)
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

  /// Notifies all listeners that the computed value has changed.
  ///
  /// This is called automatically when dependencies change. You typically
  /// don't need to call this manually.
  @protected
  void onPropertyChanged() => notifyListeners();

  /// Listens to value changes on this computed property.
  ///
  /// Returns a disposal function that removes the listener when called.
  ///
  /// Example:
  /// ```dart
  /// final dispose = totalPrice.propertyChanged(() {
  ///   print('Total changed to: ${totalPrice.value}');
  /// });
  /// // Later:
  /// dispose();
  /// ```
  VoidCallback propertyChanged(VoidCallback listener) {
    super.addListener(listener);
    return () => super.removeListener(listener);
  }

  /// Gets the current computed value and reports access for automatic tracking.
  ///
  /// Returns the cached value if available, otherwise recomputes.
  /// When accessed within a Bind.observer builder, this property will be
  /// automatically subscribed to for rebuilds.
  T get value {
    // Report access for dependency tracking (no-op if not tracking)
    DependencyTracker.reportAccess(this);
    
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
