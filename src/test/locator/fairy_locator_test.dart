import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/locator/fairy_locator.dart';

void main() {
  group('FairyLocator', () {
    late FairyLocator locator;

    setUp(() {
      locator = FairyLocator.instance;
      locator.clear(); // Clean slate for each test
    });

    tearDown(() {
      locator.clear(); // Clean up after each test
    });

    group('singleton pattern', () {
      test('should return same instance', () {
        final instance1 = FairyLocator.instance;
        final instance2 = FairyLocator.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });

      test('should maintain state across accesses', () {
        final locator1 = FairyLocator.instance;
        locator1.registerSingleton<TestService>(TestService());
        
        final locator2 = FairyLocator.instance;
        expect(locator2.contains<TestService>(), isTrue);
      });
    });

    group('registerSingleton()', () {
      test('should register and retrieve singleton instance', () {
        final service = TestService();
        locator.registerSingleton<TestService>(service);
        
        final retrieved = locator.get<TestService>();
        expect(identical(retrieved, service), isTrue);
      });

      test('should return same instance on multiple gets', () {
        final service = TestService();
        locator.registerSingleton<TestService>(service);
        
        final retrieved1 = locator.get<TestService>();
        final retrieved2 = locator.get<TestService>();
        final retrieved3 = locator.get<TestService>();
        
        expect(identical(retrieved1, retrieved2), isTrue);
        expect(identical(retrieved2, retrieved3), isTrue);
      });

      test('should throw if type already registered', () {
        locator.registerSingleton<TestService>(TestService());
        
        expect(
          () => locator.registerSingleton<TestService>(TestService()),
          throwsStateError,
        );
      });

      test('should throw if type already registered as factory', () {
        locator.registerFactory<TestService>(() => TestService());
        
        expect(
          () => locator.registerSingleton<TestService>(TestService()),
          throwsStateError,
        );
      });

      test('should support multiple different types', () {
        final service = TestService();
        final repository = TestRepository();
        final logger = TestLogger();
        
        locator.registerSingleton<TestService>(service);
        locator.registerSingleton<TestRepository>(repository);
        locator.registerSingleton<TestLogger>(logger);
        
        expect(identical(locator.get<TestService>(), service), isTrue);
        expect(identical(locator.get<TestRepository>(), repository), isTrue);
        expect(identical(locator.get<TestLogger>(), logger), isTrue);
      });

      test('should support interface and implementation', () {
        final impl = ConcreteService();
        locator.registerSingleton<AbstractService>(impl);
        
        final retrieved = locator.get<AbstractService>();
        expect(retrieved, isA<ConcreteService>());
        expect(identical(retrieved, impl), isTrue);
      });
    });

    group('registerFactory()', () {
      test('should register and retrieve from factory', () {
        var createCount = 0;
        locator.registerFactory<TestService>(() {
          createCount++;
          return TestService();
        });
        
        final instance = locator.get<TestService>();
        expect(instance, isA<TestService>());
        expect(createCount, equals(1));
      });

      test('should create new instance on each get', () {
        locator.registerFactory<TestService>(() => TestService());
        
        final instance1 = locator.get<TestService>();
        final instance2 = locator.get<TestService>();
        final instance3 = locator.get<TestService>();
        
        expect(identical(instance1, instance2), isFalse);
        expect(identical(instance2, instance3), isFalse);
      });

      test('should call factory function each time', () {
        var callCount = 0;
        locator.registerFactory<TestService>(() {
          callCount++;
          return TestService();
        });
        
        locator.get<TestService>();
        expect(callCount, equals(1));
        
        locator.get<TestService>();
        expect(callCount, equals(2));
        
        locator.get<TestService>();
        expect(callCount, equals(3));
      });

      test('should throw if type already registered', () {
        locator.registerFactory<TestService>(() => TestService());
        
        expect(
          () => locator.registerFactory<TestService>(() => TestService()),
          throwsStateError,
        );
      });

      test('should throw if type already registered as singleton', () {
        locator.registerSingleton<TestService>(TestService());
        
        expect(
          () => locator.registerFactory<TestService>(() => TestService()),
          throwsStateError,
        );
      });
    });

    group('registerLazySingleton()', () {
      test('should not create instance until first get', () {
        var createCount = 0;
        locator.registerLazySingleton<TestService>(() {
          createCount++;
          return TestService();
        });
        
        expect(createCount, equals(0)); // Not created yet
        
        locator.get<TestService>();
        expect(createCount, equals(1)); // Created on first get
      });

      test('should return same instance on subsequent gets', () {
        locator.registerLazySingleton<TestService>(() => TestService());
        
        final instance1 = locator.get<TestService>();
        final instance2 = locator.get<TestService>();
        final instance3 = locator.get<TestService>();
        
        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });

      test('should only call factory once', () {
        var callCount = 0;
        locator.registerLazySingleton<TestService>(() {
          callCount++;
          return TestService();
        });
        
        locator.get<TestService>();
        locator.get<TestService>();
        locator.get<TestService>();
        
        expect(callCount, equals(1)); // Only called once
      });

      test('should throw if type already registered', () {
        locator.registerLazySingleton<TestService>(() => TestService());
        
        expect(
          () => locator.registerLazySingleton<TestService>(() => TestService()),
          throwsStateError,
        );
      });
    });

    group('get<T>()', () {
      test('should retrieve registered singleton', () {
        final service = TestService();
        locator.registerSingleton<TestService>(service);
        
        final retrieved = locator.get<TestService>();
        expect(identical(retrieved, service), isTrue);
      });

      test('should retrieve from factory', () {
        locator.registerFactory<TestService>(() => TestService());
        
        final retrieved = locator.get<TestService>();
        expect(retrieved, isA<TestService>());
      });

      test('should throw if type not registered', () {
        expect(
          () => locator.get<TestService>(),
          throwsStateError,
        );
      });

      test('should throw with helpful error message', () {
        try {
          locator.get<TestService>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('No registration found'));
          expect(e.toString(), contains('TestService'));
          expect(e.toString(), contains('registerSingleton'));
        }
      });

      test('should work with generics', () {
        locator.registerSingleton<List<String>>(['a', 'b']);
        
        final list = locator.get<List<String>>();
        expect(list, equals(['a', 'b']));
      });
    });

    group('contains<T>()', () {
      test('should return false when type not registered', () {
        expect(locator.contains<TestService>(), isFalse);
      });

      test('should return true for registered singleton', () {
        locator.registerSingleton<TestService>(TestService());
        expect(locator.contains<TestService>(), isTrue);
      });

      test('should return true for registered factory', () {
        locator.registerFactory<TestService>(() => TestService());
        expect(locator.contains<TestService>(), isTrue);
      });

      test('should return true for registered lazy singleton', () {
        locator.registerLazySingleton<TestService>(() => TestService());
        expect(locator.contains<TestService>(), isTrue);
      });

      test('should return true even for lazy singleton before first get', () {
        locator.registerLazySingleton<TestService>(() => TestService());
        expect(locator.contains<TestService>(), isTrue);
        // Haven't called get yet, but should still return true
      });

      test('should work for multiple types', () {
        locator.registerSingleton<TestService>(TestService());
        locator.registerFactory<TestRepository>(() => TestRepository());
        
        expect(locator.contains<TestService>(), isTrue);
        expect(locator.contains<TestRepository>(), isTrue);
        expect(locator.contains<TestLogger>(), isFalse);
      });
    });

    group('unregister<T>()', () {
      test('should remove singleton registration', () {
        locator.registerSingleton<TestService>(TestService());
        expect(locator.contains<TestService>(), isTrue);
        
        locator.unregister<TestService>();
        expect(locator.contains<TestService>(), isFalse);
      });

      test('should remove factory registration', () {
        locator.registerFactory<TestService>(() => TestService());
        expect(locator.contains<TestService>(), isTrue);
        
        locator.unregister<TestService>();
        expect(locator.contains<TestService>(), isFalse);
      });

      test('should remove lazy singleton registration', () {
        locator.registerLazySingleton<TestService>(() => TestService());
        expect(locator.contains<TestService>(), isTrue);
        
        locator.unregister<TestService>();
        expect(locator.contains<TestService>(), isFalse);
      });

      test('should allow re-registration after unregister', () {
        locator.registerSingleton<TestService>(TestService());
        locator.unregister<TestService>();
        
        expect(
          () => locator.registerSingleton<TestService>(TestService()),
          returnsNormally,
        );
      });

      test('should not throw if type not registered', () {
        expect(() => locator.unregister<TestService>(), returnsNormally);
      });

      test('should not dispose instances automatically', () {
        final service = DisposableService();
        locator.registerSingleton<DisposableService>(service);
        
        locator.unregister<DisposableService>();
        
        // Service should NOT be disposed automatically
        expect(service.isDisposed, isFalse);
      });
    });

    group('clear()', () {
      test('should remove all registrations', () {
        locator.registerSingleton<TestService>(TestService());
        locator.registerFactory<TestRepository>(() => TestRepository());
        locator.registerLazySingleton<TestLogger>(() => TestLogger());
        
        expect(locator.contains<TestService>(), isTrue);
        expect(locator.contains<TestRepository>(), isTrue);
        expect(locator.contains<TestLogger>(), isTrue);
        
        locator.clear();
        
        expect(locator.contains<TestService>(), isFalse);
        expect(locator.contains<TestRepository>(), isFalse);
        expect(locator.contains<TestLogger>(), isFalse);
      });

      test('should allow new registrations after clear', () {
        locator.registerSingleton<TestService>(TestService());
        locator.clear();
        
        expect(
          () => locator.registerSingleton<TestService>(TestService()),
          returnsNormally,
        );
      });

      test('should not throw if already empty', () {
        expect(() => locator.clear(), returnsNormally);
      });
    });

    group('reset()', () {
      test('should work same as clear', () {
        locator.registerSingleton<TestService>(TestService());
        locator.registerFactory<TestRepository>(() => TestRepository());
        
        locator.reset();
        
        expect(locator.contains<TestService>(), isFalse);
        expect(locator.contains<TestRepository>(), isFalse);
      });
    });

    group('integration scenarios', () {
      test('should handle complex dependency hierarchy', () {
        // Register dependencies
        locator.registerSingleton<TestLogger>(TestLogger());
        locator.registerSingleton<TestRepository>(TestRepository());
        locator.registerFactory<TestService>(() {
          return TestService();
        });
        
        // Retrieve and verify
        final logger = locator.get<TestLogger>();
        final repo = locator.get<TestRepository>();
        final service1 = locator.get<TestService>();
        final service2 = locator.get<TestService>();
        
        expect(identical(logger, locator.get<TestLogger>()), isTrue);
        expect(identical(repo, locator.get<TestRepository>()), isTrue);
        expect(identical(service1, service2), isFalse); // Factory creates new
      });

      test('should handle mixed registration types', () {
        // Mix of singleton, factory, and lazy
        locator.registerSingleton<TestService>(TestService());
        locator.registerFactory<TestRepository>(() => TestRepository());
        locator.registerLazySingleton<TestLogger>(() => TestLogger());
        
        // All should be retrievable
        expect(locator.get<TestService>(), isA<TestService>());
        expect(locator.get<TestRepository>(), isA<TestRepository>());
        expect(locator.get<TestLogger>(), isA<TestLogger>());
      });

      test('should handle unregister and re-register correctly', () {
        final service1 = TestService();
        locator.registerSingleton<TestService>(service1);
        
        expect(identical(locator.get<TestService>(), service1), isTrue);
        
        locator.unregister<TestService>();
        
        final service2 = TestService();
        locator.registerSingleton<TestService>(service2);
        
        expect(identical(locator.get<TestService>(), service2), isTrue);
        expect(identical(service1, service2), isFalse);
      });

      test('should maintain type safety', () {
        locator.registerSingleton<TestService>(TestService());
        locator.registerSingleton<TestRepository>(TestRepository());
        
        final service = locator.get<TestService>();
        final repo = locator.get<TestRepository>();
        
        expect(service, isA<TestService>());
        expect(repo, isA<TestRepository>());
        expect(service, isNot(isA<TestRepository>()));
      });

      test('should work with abstract types', () {
        locator.registerSingleton<AbstractService>(ConcreteService());
        
        final service = locator.get<AbstractService>();
        expect(service, isA<ConcreteService>());
      });

      test('should handle lazy initialization correctly', () {
        var initializationOrder = <String>[];
        
        locator.registerLazySingleton<TestService>(() {
          initializationOrder.add('service');
          return TestService();
        });
        
        locator.registerLazySingleton<TestRepository>(() {
          initializationOrder.add('repo');
          return TestRepository();
        });
        
        // Nothing created yet
        expect(initializationOrder, isEmpty);
        
        // Get repository first
        locator.get<TestRepository>();
        expect(initializationOrder, equals(['repo']));
        
        // Then get service
        locator.get<TestService>();
        expect(initializationOrder, equals(['repo', 'service']));
        
        // Getting again shouldn't re-create
        locator.get<TestRepository>();
        locator.get<TestService>();
        expect(initializationOrder, equals(['repo', 'service']));
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
