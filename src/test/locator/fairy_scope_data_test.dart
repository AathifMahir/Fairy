import 'package:fairy/fairy.dart';
import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FairyScopeData', () {
    group('Registration', () {
      test('should register ViewModel successfully', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm);

        expect(scopeData.contains<_TestViewModel>(), isTrue);
        expect(scopeData.get<_TestViewModel>(), same(vm));
      });

      test('should register ViewModel with ownership tracking', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm, owned: true);

        expect(scopeData.contains<_TestViewModel>(), isTrue);
        
        // Dispose scope should dispose owned VM
        scopeData.dispose();
        expect(vm.isDisposed, isTrue);
      });

      test('should register ViewModel without ownership', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm, owned: false);

        expect(scopeData.contains<_TestViewModel>(), isTrue);
        
        // Dispose scope should NOT dispose non-owned VM
        scopeData.dispose();
        expect(vm.isDisposed, isFalse);
      });

      test('should throw when registering duplicate ViewModel type', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _TestViewModel();

        scopeData.register(vm1);

        expect(
          () => scopeData.register(vm2),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('_TestViewModel'),
                contains('already registered'),
                contains('Each scope can only contain one instance'),
              ]),
            ),
          ),
        );
      });

      test('should throw helpful error message for duplicate registration', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _TestViewModel();

        scopeData.register(vm1);

        try {
          scopeData.register(vm2);
          fail('Should have thrown StateError');
        } on StateError catch (e) {
          expect(e.message, contains('_TestViewModel'));
          expect(e.message, contains('already registered'));
          expect(e.message, contains('different ViewModel classes'));
        }
      });
    });

    group('Dynamic Registration', () {
      test('should register ViewModel using runtime type', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm);

        expect(scopeData.registry.containsKey(_TestViewModel), isTrue);
        expect(scopeData.registry[_TestViewModel], same(vm));
      });

      test('should register with ownership tracking', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.registerDynamic(vm, owned: true);

        scopeData.dispose();
        expect(vm.isDisposed, isTrue);
      });

      test('should throw when registering duplicate ViewModel type', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _TestViewModel();

        scopeData.registerDynamic(vm1);

        expect(
          () => scopeData.registerDynamic(vm2),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already registered'),
            ),
          ),
        );
      });

      test('should allow different ViewModel types', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _AnotherViewModel();

        scopeData.registerDynamic(vm1);
        scopeData.registerDynamic(vm2);

        expect(scopeData.registry.length, equals(2));
        expect(scopeData.registry[_TestViewModel], same(vm1));
        expect(scopeData.registry[_AnotherViewModel], same(vm2));
      });
    });

    group('Retrieval', () {
      test('should retrieve registered ViewModel', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm);

        final retrieved = scopeData.get<_TestViewModel>();
        expect(retrieved, same(vm));
      });

      test('should throw when retrieving unregistered ViewModel', () {
        final scopeData = FairyScopeData();

        expect(
          () => scopeData.get<_TestViewModel>(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No ViewModel of type _TestViewModel found'),
            ),
          ),
        );
      });

      test('should throw when retrieving disposed ViewModel', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm);
        vm.dispose();

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
    });

    group('Contains Check', () {
      test('should return true for registered ViewModel', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm);

        expect(scopeData.contains<_TestViewModel>(), isTrue);
      });

      test('should return false for unregistered ViewModel', () {
        final scopeData = FairyScopeData();

        expect(scopeData.contains<_TestViewModel>(), isFalse);
      });

      test('should return true even for disposed ViewModel', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm);
        vm.dispose();

        // Still registered, just disposed
        expect(scopeData.contains<_TestViewModel>(), isTrue);
      });
    });

    group('Disposal', () {
      test('should dispose only owned ViewModels', () {
        final scopeData = FairyScopeData();
        final ownedVm = _TestViewModel();
        final notOwnedVm = _AnotherViewModel();

        scopeData.register(ownedVm, owned: true);
        scopeData.register(notOwnedVm, owned: false);

        scopeData.dispose();

        expect(ownedVm.isDisposed, isTrue);
        expect(notOwnedVm.isDisposed, isFalse);
      });

      test('should dispose ViewModels in reverse order', () {
        final scopeData = FairyScopeData();
        final order = <String>[];

        final vm1 = _FirstViewModel()..onDispose = () => order.add('first');
        final vm2 = _SecondViewModel()..onDispose = () => order.add('second');
        final vm3 = _ThirdViewModel()..onDispose = () => order.add('third');

        scopeData.registerDynamic(vm1, owned: true);
        scopeData.registerDynamic(vm2, owned: true);
        scopeData.registerDynamic(vm3, owned: true);

        scopeData.dispose();

        expect(order, equals(['third', 'second', 'first']));
      });

      test('should clear registry after disposal', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm, owned: true);

        scopeData.dispose();

        expect(scopeData.registry.isEmpty, isTrue);
        expect(scopeData.contains<_TestViewModel>(), isFalse);
      });

      test('should handle disposal of already-disposed ViewModels', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm, owned: true);
        
        // Manually dispose VM before scope disposal
        vm.dispose();

        // Should not throw
        expect(() => scopeData.dispose(), returnsNormally);
      });

      test('should be safe to call dispose multiple times', () {
        final scopeData = FairyScopeData();
        final vm = _TestViewModel();

        scopeData.register(vm, owned: true);

        scopeData.dispose();
        expect(vm.isDisposed, isTrue);

        // Second disposal should be safe
        expect(() => scopeData.dispose(), returnsNormally);
      });
    });

    group('Mixed Registration Types', () {
      test('should handle both register() and registerDynamic()', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _AnotherViewModel();

        scopeData.register(vm1);
        scopeData.registerDynamic(vm2);

        expect(scopeData.contains<_TestViewModel>(), isTrue);
        expect(scopeData.registry.containsKey(_AnotherViewModel), isTrue);
      });

      test('should prevent duplicates across both registration methods', () {
        final scopeData = FairyScopeData();
        final vm1 = _TestViewModel();
        final vm2 = _TestViewModel();

        scopeData.register(vm1);

        expect(
          () => scopeData.registerDynamic(vm2),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}

// Test ViewModels

class _TestViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
}

class _AnotherViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
}

class _FirstViewModel extends ObservableObject {
  void Function()? onDispose;

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}

class _SecondViewModel extends ObservableObject {
  void Function()? onDispose;

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}

class _ThirdViewModel extends ObservableObject {
  void Function()? onDispose;

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}
