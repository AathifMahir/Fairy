/// A global dependency injection container for app-wide services and ViewModels.
///
/// [FairyLocator] is a singleton that provides service location capabilities
/// throughout your application. It supports both singleton and factory registrations.
///
/// **Usage Guidelines:**
/// - Use for truly app-wide services (API clients, repositories, etc.)
/// - Use for ViewModels that need to be accessible across multiple screens
/// - For scoped ViewModels (page-specific), prefer using [FairyScope] instead
///
/// Example:
/// ```dart
/// void main() {
///   // Register services
///   FairyLocator.instance.registerSingleton<ApiService>(ApiService());
///   FairyLocator.instance.registerFactory<Logger>(() => Logger());
///
///   // Register app-wide ViewModels
///   FairyLocator.instance.registerSingleton<AppViewModel>(AppViewModel());
///
///   runApp(MyApp());
/// }
///
/// // Access anywhere
/// final api = FairyLocator.instance.get<ApiService>();
/// ```
class FairyLocator {
  FairyLocator._internal();

  /// The singleton instance of [FairyLocator].
  static final FairyLocator instance = FairyLocator._internal();

  final Map<Type, Object> _singletons = {};
  final Map<Type, Function> _factories = {};

  /// Registers a singleton instance of type [T].
  ///
  /// The same [instance] will be returned on every call to [get<T>].
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// final service = MyService();
  /// FairyLocator.instance.registerSingleton<MyService>(service);
  /// ```
  void registerSingleton<T extends Object>(T instance) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    _singletons[T] = instance;
  }

  /// Registers a factory function for type [T].
  ///
  /// The [factory] function will be called each time [get<T>] is invoked,
  /// creating a new instance on each request.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// FairyLocator.instance.registerFactory<Logger>(() => Logger());
  /// ```
  void registerFactory<T extends Object>(T Function() factory) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    _factories[T] = factory;
  }

  /// Registers a lazy singleton of type [T].
  ///
  /// The [factory] is called only on the first [get<T>] request, and the
  /// result is cached for subsequent calls.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// FairyLocator.instance.registerLazySingleton<DatabaseService>(
  ///   () => DatabaseService(),
  /// );
  /// ```
  void registerLazySingleton<T extends Object>(T Function() factory) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    _factories[T] = () {
      final instance = factory();
      _singletons[T] = instance;
      _factories.remove(T);
      return instance;
    };
  }

  /// Retrieves an instance of type [T].
  ///
  /// Returns the registered singleton or calls the factory function.
  /// Throws [StateError] if no registration exists for type [T].
  ///
  /// Example:
  /// ```dart
  /// final service = FairyLocator.instance.get<MyService>();
  /// ```
  T get<T extends Object>() {
    // Check singletons first
    if (_singletons.containsKey(T)) {
      return _singletons[T]! as T;
    }

    // Check factories
    if (_factories.containsKey(T)) {
      final factory = _factories[T]! as T Function();
      return factory();
    }

    throw StateError('No registration found for type $T. '
        'Make sure to register it using registerSingleton, registerFactory, or registerLazySingleton.');
  }

  /// Checks if a registration exists for type [T].
  ///
  /// Returns `true` if [T] has been registered, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (FairyLocator.instance.contains<MyService>()) {
  ///   // Service is registered
  /// }
  /// ```
  bool contains<T extends Object>() => _singletons.containsKey(T) || _factories.containsKey(T);

  /// Unregisters the type [T] from the locator.
  ///
  /// **Warning:** This does NOT call `dispose()` on the instance.
  /// If the registered instance is disposable, you must dispose it manually
  /// before unregistering.
  ///
  /// Example:
  /// ```dart
  /// final vm = FairyLocator.instance.get<MyViewModel>();
  /// vm.dispose();
  /// FairyLocator.instance.unregister<MyViewModel>();
  /// ```
  void unregister<T extends Object>() {
    _singletons.remove(T);
    _factories.remove(T);
  }

  /// Clears all registrations.
  ///
  /// **Warning:** This does NOT call `dispose()` on any instances.
  /// Use with caution, typically only for testing or app teardown.
  void clear() {
    _singletons.clear();
    _factories.clear();
  }

  /// Resets the locator to its initial empty state.
  ///
  /// Equivalent to [clear]. Provided for API compatibility.
  void reset() => clear();
}
