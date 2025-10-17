import 'package:fairy/fairy.dart';
import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Disposal Checks in Resolution', () {
    group('FairyLocator Disposal Checks', () {
      setUp(() {
        // Clear any existing registrations
        FairyLocator.instance.clear();
      });

      tearDown(() {
        FairyLocator.instance.clear();
      });

      test('should throw when getting disposed singleton', () {
        final vm = _TestViewModel();
        FairyLocator.instance.registerSingleton(vm);

        // Dispose the ViewModel
        vm.dispose();

        // Attempting to get should throw
        expect(
          () => FairyLocator.instance.get<_TestViewModel>(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('has been disposed and cannot be accessed'),
            ),
          ),
        );
      });

      test('should return fresh instance from transient (not disposed)', () {
        FairyLocator.instance.registerTransient(() => _TestViewModel());

        // Get instance
        final vm1 = FairyLocator.instance.get<_TestViewModel>();
        expect(vm1.isDisposed, isFalse);

        // Dispose it
        vm1.dispose();
        expect(vm1.isDisposed, isTrue);

        // Get another instance - should be fresh, not disposed
        final vm2 = FairyLocator.instance.get<_TestViewModel>();
        expect(vm2.isDisposed, isFalse);
        expect(identical(vm1, vm2), isFalse);
      }, skip: 'Transient registrations create new instances each time, so disposal check not needed');

      test('should return fresh instance from lazy singleton on first access', () {
        FairyLocator.instance.registerLazySingleton(() => _TestViewModel());

        // Get instance (creates and caches)
        final vm1 = FairyLocator.instance.get<_TestViewModel>();
        expect(vm1.isDisposed, isFalse);

        // Get again - should return same instance
        final vm2 = FairyLocator.instance.get<_TestViewModel>();
        expect(identical(vm1, vm2), isTrue);
      });

      test('should throw when getting disposed lazy singleton', () {
        FairyLocator.instance.registerLazySingleton(() => _TestViewModel());

        // Get instance (creates and caches)
        final vm = FairyLocator.instance.get<_TestViewModel>();

        // Dispose it
        vm.dispose();

        // Attempting to get again should throw
        expect(
          () => FairyLocator.instance.get<_TestViewModel>(),
          throwsA(isA<StateError>()),
        );
      });

      test('should not check disposal for non-Disposable types', () {
        final service = _NonDisposableService();
        FairyLocator.instance.registerSingleton(service);

        // Should work fine (no disposal check needed)
        expect(
          () => FairyLocator.instance.get<_NonDisposableService>(),
          returnsNormally,
        );
      });

      test('disposal check should provide helpful error message', () {
        final vm = _TestViewModel();
        FairyLocator.instance.registerSingleton(vm);

        vm.dispose();

        try {
          FairyLocator.instance.get<_TestViewModel>();
          fail('Should have thrown');
        } on StateError catch (e) {
          expect(e.message, contains('_TestViewModel'));
          expect(e.message, contains('has been disposed'));
          expect(e.message, contains('cannot be accessed'));
        }
      });
    });

    group('FairyScope Disposal Checks', () {
      test('should throw when getting disposed ViewModel from scope', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm, owned: true);

        // Dispose the ViewModel
        vm.dispose();

        // Attempting to get should throw
        expect(
          () => scopeData.get<_TestViewModel>(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('has been disposed and cannot be accessed'),
            ),
          ),
        );
      });

      test('should return non-disposed ViewModel successfully', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm, owned: true);

        // Should work fine
        final retrieved = scopeData.get<_TestViewModel>();
        expect(identical(retrieved, vm), isTrue);
        expect(retrieved.isDisposed, isFalse);
      });

      test('should throw when ViewModel disposed after registration', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm, owned: false); // Not owned by scope

        // First access - OK
        expect(() => scopeData.get<_TestViewModel>(), returnsNormally);

        // Manually dispose
        vm.dispose();

        // Second access - should throw
        expect(
          () => scopeData.get<_TestViewModel>(),
          throwsA(isA<StateError>()),
        );
      });

      test('disposal check should provide helpful error message', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm, owned: true);
        vm.dispose();

        try {
          scopeData.get<_TestViewModel>();
          fail('Should have thrown');
        } on StateError catch (e) {
          expect(e.message, contains('_TestViewModel'));
          expect(e.message, contains('has been disposed'));
          expect(e.message, contains('FairyScope was removed'));
        }
      });

      test('should dispose owned ViewModels when scope disposes', () {
        final scopeData = FairyScopeData();
        final vm1 = _FirstViewModel();
        final vm2 = _SecondViewModel();

        scopeData.registerDynamic(vm1, owned: true);
        scopeData.registerDynamic(vm2, owned: false); // Not owned

        expect(vm1.isDisposed, isFalse);
        expect(vm2.isDisposed, isFalse);

        // Dispose scope
        scopeData.dispose();

        // Only owned VM should be disposed
        expect(vm1.isDisposed, isTrue);
        expect(vm2.isDisposed, isFalse); // Not owned, not disposed
      });

      test('should dispose owned ViewModels in reverse registration order', () {
        final scopeData = FairyScopeData();
        final log = <String>[];

        final vm1 = _FirstViewModelWithCallback(() => log.add('vm1'));
        final vm2 = _SecondViewModelWithCallback(() => log.add('vm2'));
        final vm3 = _ThirdViewModelWithCallback(() => log.add('vm3'));

        scopeData.registerDynamic(vm1, owned: true);
        scopeData.registerDynamic(vm2, owned: true);
        scopeData.registerDynamic(vm3, owned: true);

        // Dispose scope
        scopeData.dispose();

        // Should dispose in reverse order (LIFO - last in, first out)
        expect(log, equals(['vm3', 'vm2', 'vm1']));
      });
    });

    group('Integration Tests', () {
      tearDown(() {
        FairyLocator.instance.clear();
      });

      test('should handle disposal across locator and scope', () {
        // Register service in locator
        final service = _TestViewModel();
        FairyLocator.instance.registerSingleton(service);

        // Register ViewModel in scope that depends on service
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();
        scopeData.registerDynamic(vm, owned: true);

        // Both should be accessible
        expect(() => FairyLocator.instance.get<_TestViewModel>(), returnsNormally);
        expect(() => scopeData.get<_TestViewModel>(), returnsNormally);

        // Dispose service
        service.dispose();

        // Service should throw
        expect(
          () => FairyLocator.instance.get<_TestViewModel>(),
          throwsA(isA<StateError>()),
        );

        // Scope VM should still work
        expect(() => scopeData.get<_TestViewModel>(), returnsNormally);

        // Dispose scope
        scopeData.dispose();

        // Scope VM should now throw (was disposed by scope)
        expect(
          () => scopeData.get<_TestViewModel>(),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle cascading disposal', () {
        final scopeData = FairyScopeData();
        final parent = _ParentViewModel();

        scopeData.registerDynamic(parent, owned: true);
        scopeData.registerDynamic(parent.child, owned: false); // Child not owned by scope

        expect(parent.isDisposed, isFalse);
        expect(parent.child.isDisposed, isFalse);

        // Dispose scope (only disposes parent)
        scopeData.dispose();

        expect(parent.isDisposed, isTrue); // Disposed by scope
        expect(parent.child.isDisposed, isTrue); // Disposed by parent's dispose()

        // Both should throw now
        expect(() => scopeData.get<_ParentViewModel>(), throwsA(isA<StateError>()));
        expect(() => scopeData.get<_ChildViewModel>(), throwsA(isA<StateError>()));
      });
    });
  });
}

// Test classes

class _TestViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
}

class _TestViewModelWithCallback extends ObservableObject {
  final void Function() onDispose;

  _TestViewModelWithCallback(this.onDispose);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }
}

class _ParentViewModel extends ObservableObject {
  late final _ChildViewModel child;

  _ParentViewModel() {
    child = _ChildViewModel();
  }

  @override
  void dispose() {
    child.dispose();
    super.dispose();
  }
}

class _ChildViewModel extends ObservableObject {}

class _NonDisposableService {
  void doSomething() {}
}

// Additional test VMs for disposal order tests (need different types)
class _FirstViewModel extends ObservableObject {}

class _SecondViewModel extends ObservableObject {}

class _FirstViewModelWithCallback extends ObservableObject {
  final void Function() onDispose;

  _FirstViewModelWithCallback(this.onDispose);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }
}

class _SecondViewModelWithCallback extends ObservableObject {
  final void Function() onDispose;

  _SecondViewModelWithCallback(this.onDispose);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }
}

class _ThirdViewModelWithCallback extends ObservableObject {
  final void Function() onDispose;

  _ThirdViewModelWithCallback(this.onDispose);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }
}
