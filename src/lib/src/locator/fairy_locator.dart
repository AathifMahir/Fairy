/// A global dependency injection container for app-wide services and ViewModels.
///
/// [FairyLocator] is a singleton that provides service location capabilities
/// throughout your application. It supports singleton, lazy singleton, async 
/// singleton, and transient registrations.
///
/// **Usage Guidelines:**
/// - Use for truly app-wide services (API clients, repositories, etc.)
/// - Use for ViewModels that need to be accessible across multiple screens
/// - For scoped ViewModels (page-specific), prefer using [FairyScope] instead
///
/// **Registration Methods:**
/// - [registerSingleton]: Register an already-created instance (eager, cached)
/// - [registerLazySingleton]: Register a factory that creates on first use (lazy, cached)
/// - [registerSingletonAsync]: Register with async initialization (eager, cached)
/// - [registerLazySingletonAsync]: Register lazy async (rarely needed, see docs)
/// - [registerTransient]: Register a factory that creates new instance each time
///
/// Example:
/// ```dart
/// void main() async {
///   // Eager singleton
///   Fairy.instance.registerSingleton<ApiService>(ApiService());
///
///   // Lazy singleton
///   Fairy.instance.registerLazySingleton<Logger>(() => Logger());
///
///   // Async singleton (await during app startup)
///   await Fairy.instance.registerSingletonAsync<DatabaseService>(
///     () async => await DatabaseService.connect(),
///   );
///
///   // Transient (new instance each time)
///   Fairy.instance.registerTransient<RequestId>(() => RequestId.generate());
///
///   runApp(MyApp());
/// }
///
/// // Access anywhere
/// final api = Fairy.instance.get<ApiService>();
/// final logger = Fairy.instance.get<Logger>();
/// ```
class FairyLocator {
  FairyLocator._internal();

  /// The singleton instance of [FairyLocator].
  static final FairyLocator instance = FairyLocator._internal();

  final Map<Type, Object> _singletons = {};
  final Map<Type, Object Function()> _factories = {};

  /// Registers a singleton instance of type [T].
  ///
  /// The same [instance] will be returned on every call to [get<T>].
  /// Use this for instances that are already created and ready to use.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// final service = MyService();
  /// Fairy.instance.registerSingleton<MyService>(service);
  /// ```
  void registerSingleton<T extends Object>(T instance) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    _singletons[T] = instance;
  }

  /// Registers a lazy singleton of type [T].
  ///
  /// The [factory] is called only on the first [get<T>] request, and the
  /// result is cached for subsequent calls. Use this for instances that are
  /// expensive to create or may not be needed immediately.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// Fairy.instance.registerLazySingleton<DatabaseService>(
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

  /// Registers a singleton with async initialization.
  ///
  /// The [factory] is called immediately and awaited. The resulting instance
  /// is stored and can be retrieved synchronously with [get<T>].
  ///
  /// Use this for services that require async initialization (e.g., database
  /// connections, API clients) but should be ready before the app starts.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// await Fairy.instance.registerSingletonAsync<DatabaseService>(
  ///   () async => await DatabaseService.connect(),
  /// );
  /// // Now available synchronously
  /// final db = Fairy.instance.get<DatabaseService>();
  /// ```
  Future<void> registerSingletonAsync<T extends Object>(
    Future<T> Function() factory,
  ) async {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    final instance = await factory();
    _singletons[T] = instance;
  }

  /// Registers a lazy singleton with async initialization.
  ///
  /// The [factory] is NOT called immediately. Instead, registration completes
  /// without awaiting. The instance will not be available until you manually
  /// trigger initialization.
  ///
  /// **Important:** Since [get<T>] is synchronous, you cannot lazily initialize
  /// async singletons on-demand. You must initialize them explicitly before use.
  ///
  /// **Recommendation:** Use [registerSingletonAsync] for eager initialization instead.
  /// Lazy async singletons are rarely needed and can lead to runtime errors if not
  /// carefully managed.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// // Register lazy async (not recommended)
  /// await Fairy.instance.registerLazySingletonAsync<ApiClient>(
  ///   () async => await ApiClient.connect(),
  /// );
  /// 
  /// // Will throw! Instance not initialized
  /// // final api = Fairy.instance.get<ApiClient>();
  /// 
  /// // Better: use eager async
  /// await Fairy.instance.registerSingletonAsync<ApiClient>(
  ///   () async => await ApiClient.connect(),
  /// );
  /// ```
  Future<void> registerLazySingletonAsync<T extends Object>(
    Future<T> Function() factory,
  ) async {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    
    // Store a sync factory that throws, requiring explicit async initialization
    _factories[T] = () {
      throw StateError(
        'Lazy async singleton of type $T has not been initialized yet.\n'
        'Lazy async singletons cannot be initialized on-demand because get<T>() is synchronous.\n'
        'Consider using registerSingletonAsync() for eager initialization instead:\n'
        '  await Fairy.instance.registerSingletonAsync<$T>(() async => ...)',
      );
    };
  }

  /// Registers a transient (factory) for type [T].
  ///
  /// The [factory] function will be called each time [get<T>] is invoked,
  /// creating a new instance on each request. No caching is performed.
  ///
  /// Use this for lightweight objects that should not be shared or cached.
  ///
  /// Throws [StateError] if a registration for type [T] already exists.
  ///
  /// Example:
  /// ```dart
  /// Fairy.instance.registerTransient<Logger>(() => Logger());
  ///
  /// final logger1 = Fairy.instance.get<Logger>(); // New instance
  /// final logger2 = Fairy.instance.get<Logger>(); // Another new instance
  /// ```
  void registerTransient<T extends Object>(T Function() factory) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('Type $T is already registered');
    }
    _factories[T] = factory;
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

    throw StateError(
      'No registration found for type $T.\n'
      'Make sure to register it using:\n'
      '  - Fairy.instance.registerSingleton<$T>(instance)\n'
      '  - Fairy.instance.registerLazySingleton<$T>(() => ...)\n'
      '  - await Fairy.instance.registerSingletonAsync<$T>(() async => ...)\n'
      '  - Fairy.instance.registerTransient<$T>(() => ...)',
    );
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
