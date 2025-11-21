import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/locator/fairy_locator.dart';

void main() {
  group('FairyLocator', () {
    setUp(() {
      FairyLocator.clear(); // Clean slate for each test
    });

    tearDown(() {
      FairyLocator.clear(); // Clean up after each test
    });

    group('registerSingleton()', () {
      test('should register and retrieve singleton instance', () {
        final service = TestService();
        FairyLocator.registerSingleton<TestService>(service);

        final retrieved = FairyLocator.get<TestService>();
        expect(identical(retrieved, service), isTrue);
      });

      test('should return same instance on multiple gets', () {
        final service = TestService();
        FairyLocator.registerSingleton<TestService>(service);

        final retrieved1 = FairyLocator.get<TestService>();
        final retrieved2 = FairyLocator.get<TestService>();
        final retrieved3 = FairyLocator.get<TestService>();

        expect(identical(retrieved1, retrieved2), isTrue);
        expect(identical(retrieved2, retrieved3), isTrue);
      });

      test('should throw if type already registered', () {
        FairyLocator.registerSingleton<TestService>(TestService());

        expect(
          () => FairyLocator.registerSingleton<TestService>(TestService()),
          throwsStateError,
        );
      });

      test('should throw if type already registered as transient', () {
        FairyLocator.registerTransient<TestService>(() => TestService());

        expect(
          () => FairyLocator.registerSingleton<TestService>(TestService()),
          throwsStateError,
        );
      });

      test('should support multiple different types', () {
        final service = TestService();
        final repository = TestRepository();
        final logger = TestLogger();

        FairyLocator.registerSingleton<TestService>(service);
        FairyLocator.registerSingleton<TestRepository>(repository);
        FairyLocator.registerSingleton<TestLogger>(logger);

        expect(identical(FairyLocator.get<TestService>(), service), isTrue);
        expect(
            identical(FairyLocator.get<TestRepository>(), repository), isTrue);
        expect(identical(FairyLocator.get<TestLogger>(), logger), isTrue);
      });

      test('should support interface and implementation', () {
        final impl = ConcreteService();
        FairyLocator.registerSingleton<AbstractService>(impl);

        final retrieved = FairyLocator.get<AbstractService>();
        expect(retrieved, isA<ConcreteService>());
        expect(identical(retrieved, impl), isTrue);
      });
    });

    group('registerTransient()', () {
      test('should register and retrieve from transient factory', () {
        var createCount = 0;
        FairyLocator.registerTransient<TestService>(() {
          createCount++;
          return TestService();
        });

        final instance = FairyLocator.get<TestService>();
        expect(instance, isA<TestService>());
        expect(createCount, equals(1));
      });

      test('should create new instance on each get', () {
        FairyLocator.registerTransient<TestService>(() => TestService());

        final instance1 = FairyLocator.get<TestService>();
        final instance2 = FairyLocator.get<TestService>();
        final instance3 = FairyLocator.get<TestService>();

        expect(identical(instance1, instance2), isFalse);
        expect(identical(instance2, instance3), isFalse);
      });

      test('should call factory function each time', () {
        var callCount = 0;
        FairyLocator.registerTransient<TestService>(() {
          callCount++;
          return TestService();
        });

        FairyLocator.get<TestService>();
        expect(callCount, equals(1));

        FairyLocator.get<TestService>();
        expect(callCount, equals(2));

        FairyLocator.get<TestService>();
        expect(callCount, equals(3));
      });

      test('should throw if type already registered', () {
        FairyLocator.registerTransient<TestService>(() => TestService());

        expect(
          () =>
              FairyLocator.registerTransient<TestService>(() => TestService()),
          throwsStateError,
        );
      });

      test('should throw if type already registered as singleton', () {
        FairyLocator.registerSingleton<TestService>(TestService());

        expect(
          () =>
              FairyLocator.registerTransient<TestService>(() => TestService()),
          throwsStateError,
        );
      });
    });

    group('registerLazySingleton()', () {
      test('should not create instance until first get', () {
        var createCount = 0;
        FairyLocator.registerLazySingleton<TestService>(() {
          createCount++;
          return TestService();
        });

        expect(createCount, equals(0)); // Not created yet

        FairyLocator.get<TestService>();
        expect(createCount, equals(1)); // Created on first get
      });

      test('should return same instance on subsequent gets', () {
        FairyLocator.registerLazySingleton<TestService>(() => TestService());

        final instance1 = FairyLocator.get<TestService>();
        final instance2 = FairyLocator.get<TestService>();
        final instance3 = FairyLocator.get<TestService>();

        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });

      test('should only call factory once', () {
        var callCount = 0;
        FairyLocator.registerLazySingleton<TestService>(() {
          callCount++;
          return TestService();
        });

        FairyLocator.get<TestService>();
        FairyLocator.get<TestService>();
        FairyLocator.get<TestService>();

        expect(callCount, equals(1)); // Only called once
      });

      test('should throw if type already registered', () {
        FairyLocator.registerLazySingleton<TestService>(() => TestService());

        expect(
          () => FairyLocator.registerLazySingleton<TestService>(
              () => TestService()),
          throwsStateError,
        );
      });
    });

    group('registerSingletonAsync()', () {
      test('should register and retrieve async singleton', () async {
        final service = AsyncService();
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async => service,
        );

        final retrieved = FairyLocator.get<AsyncService>();
        expect(identical(retrieved, service), isTrue);
      });

      test('should await async initialization', () async {
        var initialized = false;
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async {
            // ignore: inference_failure_on_instance_creation
            await Future.delayed(const Duration(milliseconds: 10));
            initialized = true;
            return AsyncService();
          },
        );

        // Should be initialized immediately after registration
        expect(initialized, isTrue);
      });

      test('should return same instance on multiple gets', () async {
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async => AsyncService(),
        );

        final retrieved1 = FairyLocator.get<AsyncService>();
        final retrieved2 = FairyLocator.get<AsyncService>();
        final retrieved3 = FairyLocator.get<AsyncService>();

        expect(identical(retrieved1, retrieved2), isTrue);
        expect(identical(retrieved2, retrieved3), isTrue);
      });

      test('should throw if type already registered', () async {
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async => AsyncService(),
        );

        await expectLater(
          FairyLocator.registerSingletonAsync<AsyncService>(
            () async => AsyncService(),
          ),
          throwsStateError,
        );
      });

      test('should throw if type already registered as singleton', () async {
        FairyLocator.registerSingleton<TestService>(TestService());

        await expectLater(
          FairyLocator.registerSingletonAsync<TestService>(
            () async => TestService(),
          ),
          throwsStateError,
        );
      });

      test('should work with complex async initialization', () async {
        var initSteps = <String>[];

        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async {
            initSteps.add('start');
            // ignore: inference_failure_on_instance_creation
            await Future.delayed(const Duration(milliseconds: 5));
            initSteps.add('connect');
            // ignore: inference_failure_on_instance_creation
            await Future.delayed(const Duration(milliseconds: 5));
            initSteps.add('ready');
            return AsyncService();
          },
        );

        expect(initSteps, equals(['start', 'connect', 'ready']));
        expect(FairyLocator.get<AsyncService>(), isA<AsyncService>());
      });

      test('should be accessible synchronously after registration', () async {
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async {
            // ignore: inference_failure_on_instance_creation
            await Future.delayed(const Duration(milliseconds: 10));
            return AsyncService();
          },
        );

        // Should not throw - already initialized
        final service = FairyLocator.get<AsyncService>();
        expect(service, isA<AsyncService>());
      });
    });

    group('registerLazySingletonAsync()', () {
      test('should register without immediate initialization', () async {
        var initialized = false;

        await FairyLocator.registerLazySingletonAsync<AsyncService>(
          () async {
            initialized = true;
            return AsyncService();
          },
        );

        // Should NOT be initialized yet
        expect(initialized, isFalse);
        expect(FairyLocator.contains<AsyncService>(), isTrue);
      });

      test('should throw when trying to get before initialization', () async {
        await FairyLocator.registerLazySingletonAsync<AsyncService>(
          () async => AsyncService(),
        );

        expect(
          () => FairyLocator.get<AsyncService>(),
          throwsStateError,
        );
      });

      test('should have helpful error message', () async {
        await FairyLocator.registerLazySingletonAsync<AsyncService>(
          () async => AsyncService(),
        );

        try {
          FairyLocator.get<AsyncService>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Lazy async singleton'));
          expect(e.toString(), contains('AsyncService'));
          expect(e.toString(), contains('not been initialized'));
          expect(e.toString(), contains('registerSingletonAsync'));
        }
      });

      test('should throw if type already registered', () async {
        await FairyLocator.registerLazySingletonAsync<AsyncService>(
          () async => AsyncService(),
        );

        await expectLater(
          FairyLocator.registerLazySingletonAsync<AsyncService>(
            () async => AsyncService(),
          ),
          throwsStateError,
        );
      });
    });

    group('get<T>()', () {
      test('should retrieve registered singleton', () {
        final service = TestService();
        FairyLocator.registerSingleton<TestService>(service);

        final retrieved = FairyLocator.get<TestService>();
        expect(identical(retrieved, service), isTrue);
      });

      test('should retrieve from transient', () {
        FairyLocator.registerTransient<TestService>(() => TestService());

        final retrieved = FairyLocator.get<TestService>();
        expect(retrieved, isA<TestService>());
      });

      test('should throw if type not registered', () {
        expect(
          () => FairyLocator.get<TestService>(),
          throwsStateError,
        );
      });

      test('should throw with helpful error message', () {
        try {
          FairyLocator.get<TestService>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('No registration found'));
          expect(e.toString(), contains('TestService'));
          expect(e.toString(), contains('registerSingleton'));
        }
      });

      test('should work with generics', () {
        FairyLocator.registerSingleton<List<String>>(['a', 'b']);

        final list = FairyLocator.get<List<String>>();
        expect(list, equals(['a', 'b']));
      });
    });

    group('contains<T>()', () {
      test('should return false when type not registered', () {
        expect(FairyLocator.contains<TestService>(), isFalse);
      });

      test('should return true for registered singleton', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);
      });

      test('should return true for registered transient', () {
        FairyLocator.registerTransient<TestService>(() => TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);
      });

      test('should return true for registered lazy singleton', () {
        FairyLocator.registerLazySingleton<TestService>(() => TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);
      });

      test('should return true even for lazy singleton before first get', () {
        FairyLocator.registerLazySingleton<TestService>(() => TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);
        // Haven't called get yet, but should still return true
      });

      test('should work for multiple types', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.registerTransient<TestRepository>(() => TestRepository());

        expect(FairyLocator.contains<TestService>(), isTrue);
        expect(FairyLocator.contains<TestRepository>(), isTrue);
        expect(FairyLocator.contains<TestLogger>(), isFalse);
      });
    });

    group('unregister<T>()', () {
      test('should remove singleton registration', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);

        FairyLocator.unregister<TestService>();
        expect(FairyLocator.contains<TestService>(), isFalse);
      });

      test('should remove transient registration', () {
        FairyLocator.registerTransient<TestService>(() => TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);

        FairyLocator.unregister<TestService>();
        expect(FairyLocator.contains<TestService>(), isFalse);
      });

      test('should remove lazy singleton registration', () {
        FairyLocator.registerLazySingleton<TestService>(() => TestService());
        expect(FairyLocator.contains<TestService>(), isTrue);

        FairyLocator.unregister<TestService>();
        expect(FairyLocator.contains<TestService>(), isFalse);
      });

      test('should allow re-registration after unregister', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.unregister<TestService>();

        expect(
          () => FairyLocator.registerSingleton<TestService>(TestService()),
          returnsNormally,
        );
      });

      test('should not throw if type not registered', () {
        expect(() => FairyLocator.unregister<TestService>(), returnsNormally);
      });

      test('should not dispose instances automatically', () {
        final service = DisposableService();
        FairyLocator.registerSingleton<DisposableService>(service);

        FairyLocator.unregister<DisposableService>();

        // Service should NOT be disposed automatically
        expect(service.isDisposed, isFalse);
      });
    });

    group('clear()', () {
      test('should remove all registrations', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.registerTransient<TestRepository>(() => TestRepository());
        FairyLocator.registerLazySingleton<TestLogger>(() => TestLogger());

        expect(FairyLocator.contains<TestService>(), isTrue);
        expect(FairyLocator.contains<TestRepository>(), isTrue);
        expect(FairyLocator.contains<TestLogger>(), isTrue);

        FairyLocator.clear();

        expect(FairyLocator.contains<TestService>(), isFalse);
        expect(FairyLocator.contains<TestRepository>(), isFalse);
        expect(FairyLocator.contains<TestLogger>(), isFalse);
      });

      test('should allow new registrations after clear', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.clear();

        expect(
          () => FairyLocator.registerSingleton<TestService>(TestService()),
          returnsNormally,
        );
      });

      test('should not throw if already empty', () {
        expect(() => FairyLocator.clear(), returnsNormally);
      });
    });

    group('reset()', () {
      test('should work same as clear', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.registerTransient<TestRepository>(() => TestRepository());

        FairyLocator.reset();

        expect(FairyLocator.contains<TestService>(), isFalse);
        expect(FairyLocator.contains<TestRepository>(), isFalse);
      });
    });

    group('integration scenarios', () {
      test('should handle complex dependency hierarchy', () {
        // Register dependencies
        FairyLocator.registerSingleton<TestLogger>(TestLogger());
        FairyLocator.registerSingleton<TestRepository>(TestRepository());
        FairyLocator.registerTransient<TestService>(() {
          return TestService();
        });

        // Retrieve and verify
        final logger = FairyLocator.get<TestLogger>();
        final repo = FairyLocator.get<TestRepository>();
        final service1 = FairyLocator.get<TestService>();
        final service2 = FairyLocator.get<TestService>();

        expect(identical(logger, FairyLocator.get<TestLogger>()), isTrue);
        expect(identical(repo, FairyLocator.get<TestRepository>()), isTrue);
        expect(identical(service1, service2), isFalse); // Transient creates new
      });

      test('should handle mixed registration types', () {
        // Mix of singleton, transient, and lazy
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.registerTransient<TestRepository>(() => TestRepository());
        FairyLocator.registerLazySingleton<TestLogger>(() => TestLogger());

        // All should be retrievable
        expect(FairyLocator.get<TestService>(), isA<TestService>());
        expect(FairyLocator.get<TestRepository>(), isA<TestRepository>());
        expect(FairyLocator.get<TestLogger>(), isA<TestLogger>());
      });

      test('should handle unregister and re-register correctly', () {
        final service1 = TestService();
        FairyLocator.registerSingleton<TestService>(service1);

        expect(identical(FairyLocator.get<TestService>(), service1), isTrue);

        FairyLocator.unregister<TestService>();

        final service2 = TestService();
        FairyLocator.registerSingleton<TestService>(service2);

        expect(identical(FairyLocator.get<TestService>(), service2), isTrue);
        expect(identical(service1, service2), isFalse);
      });

      test('should maintain type safety', () {
        FairyLocator.registerSingleton<TestService>(TestService());
        FairyLocator.registerSingleton<TestRepository>(TestRepository());

        final service = FairyLocator.get<TestService>();
        final repo = FairyLocator.get<TestRepository>();

        expect(service, isA<TestService>());
        expect(repo, isA<TestRepository>());
        expect(service, isNot(isA<TestRepository>()));
      });

      test('should work with abstract types', () {
        FairyLocator.registerSingleton<AbstractService>(ConcreteService());

        final service = FairyLocator.get<AbstractService>();
        expect(service, isA<ConcreteService>());
      });

      test('should handle lazy initialization correctly', () {
        var initializationOrder = <String>[];

        FairyLocator.registerLazySingleton<TestService>(() {
          initializationOrder.add('service');
          return TestService();
        });

        FairyLocator.registerLazySingleton<TestRepository>(() {
          initializationOrder.add('repo');
          return TestRepository();
        });

        // Nothing created yet
        expect(initializationOrder, isEmpty);

        // Get repository first
        FairyLocator.get<TestRepository>();
        expect(initializationOrder, equals(['repo']));

        // Then get service
        FairyLocator.get<TestService>();
        expect(initializationOrder, equals(['repo', 'service']));

        // Getting again shouldn't re-create
        FairyLocator.get<TestRepository>();
        FairyLocator.get<TestService>();
        expect(initializationOrder, equals(['repo', 'service']));
      });

      test('should handle mixed sync and async registrations', () async {
        // Mix of sync and async registrations
        FairyLocator.registerSingleton<TestService>(TestService());
        await FairyLocator.registerSingletonAsync<AsyncService>(
          () async => AsyncService(),
        );
        FairyLocator.registerLazySingleton<TestLogger>(() => TestLogger());
        FairyLocator.registerTransient<TestRepository>(() => TestRepository());

        // All should be retrievable
        expect(FairyLocator.get<TestService>(), isA<TestService>());
        expect(FairyLocator.get<AsyncService>(), isA<AsyncService>());
        expect(FairyLocator.get<TestLogger>(), isA<TestLogger>());
        expect(FairyLocator.get<TestRepository>(), isA<TestRepository>());

        // Verify singleton vs transient behavior
        final async1 = FairyLocator.get<AsyncService>();
        final async2 = FairyLocator.get<AsyncService>();
        expect(identical(async1, async2), isTrue); // Async singleton

        final repo1 = FairyLocator.get<TestRepository>();
        final repo2 = FairyLocator.get<TestRepository>();
        expect(identical(repo1, repo2), isFalse); // Transient
      });

      test('should support async initialization in app startup pattern',
          () async {
        // Simulating app startup with multiple async services
        final futures = <Future<void>>[];

        futures.add(
          FairyLocator.registerSingletonAsync<AsyncService>(
            () async {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              return AsyncService();
            },
          ),
        );

        futures.add(
          FairyLocator.registerSingletonAsync<TestLogger>(
            () async {
              await Future<void>.delayed(const Duration(milliseconds: 3));
              return TestLogger();
            },
          ),
        );

        // Wait for all async initializations
        await Future.wait(futures);

        // All services should be ready
        expect(FairyLocator.get<AsyncService>(), isA<AsyncService>());
        expect(FairyLocator.get<TestLogger>(), isA<TestLogger>());
      });
    });
  });
}

// Test helper classes

class TestService {}

class TestRepository {}

class TestLogger {}

abstract class AbstractService {}

class ConcreteService implements AbstractService {}

class DisposableService {
  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
  }
}

class AsyncService {
  AsyncService();

  static Future<AsyncService> create() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return AsyncService();
  }
}
