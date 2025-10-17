import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/locator/fairy_locator.dart';

void main() {
  group('FairyScopeData', () {
    late FairyScopeData data;

    setUp(() {
      data = FairyScopeData();
    });

    group('register()', () {
      test('should register ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm);

        expect(data.contains<TestViewModel>(), isTrue);
        expect(identical(data.get<TestViewModel>(), vm), isTrue);
      });

      test('should register owned ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);

        expect(data.contains<TestViewModel>(), isTrue);
      });

      test('should register non-owned ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: false);

        expect(data.contains<TestViewModel>(), isTrue);
      });

      test('should allow registering multiple types', () {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();

        data.register<TestViewModel>(vm1);
        data.register<AnotherViewModel>(vm2);

        expect(data.contains<TestViewModel>(), isTrue);
        expect(data.contains<AnotherViewModel>(), isTrue);
      });
    });

    group('get<T>()', () {
      test('should retrieve registered ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm);

        final retrieved = data.get<TestViewModel>();
        expect(identical(retrieved, vm), isTrue);
      });

      test('should throw if ViewModel not found', () {
        expect(
          () => data.get<TestViewModel>(),
          throwsStateError,
        );
      });

      test('should throw with helpful error message', () {
        try {
          data.get<TestViewModel>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('No ViewModel'));
          expect(e.toString(), contains('TestViewModel'));
          expect(e.toString(), contains('FairyScope'));
        }
      });
    });

    group('contains<T>()', () {
      test('should return false when not registered', () {
        expect(data.contains<TestViewModel>(), isFalse);
      });

      test('should return true when registered', () {
        data.register<TestViewModel>(TestViewModel());
        expect(data.contains<TestViewModel>(), isTrue);
      });
    });

    group('dispose()', () {
      test('should dispose owned ViewModels', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);

        expect(vm.isDisposed, isFalse);

        data.dispose();

        expect(vm.isDisposed, isTrue);
      });

      test('should NOT dispose non-owned ViewModels', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: false);

        expect(vm.isDisposed, isFalse);

        data.dispose();

        expect(vm.isDisposed, isFalse);
      });

      test('should dispose only owned ViewModels in mixed scenario', () {
        final ownedVm = TestViewModel();
        final suppliedVm = AnotherViewModel();

        data.register<TestViewModel>(ownedVm, owned: true);
        data.register<AnotherViewModel>(suppliedVm, owned: false);

        data.dispose();

        expect(ownedVm.isDisposed, isTrue);
        expect(suppliedVm.isDisposed, isFalse);
      });

      test('should clear registry after dispose', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);

        data.dispose();

        expect(data.contains<TestViewModel>(), isFalse);
      });

      test('should handle multiple owned ViewModels', () {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();
        final vm3 = ThirdViewModel();

        data.register<TestViewModel>(vm1, owned: true);
        data.register<AnotherViewModel>(vm2, owned: true);
        data.register<ThirdViewModel>(vm3, owned: true);

        data.dispose();

        expect(vm1.isDisposed, isTrue);
        expect(vm2.isDisposed, isTrue);
        expect(vm3.isDisposed, isTrue);
      });
    });
  });

  group('FairyScope widget', () {
    testWidgets('should provide scope data to descendants', (tester) async {
      FairyScopeData? capturedData;

      await tester.pumpWidget(
        FairyScope(
          viewModel: (_) => TestViewModel(),
          child: Builder(
            builder: (context) {
              capturedData = FairyScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!.contains<TestViewModel>(), isTrue);
    });

    testWidgets('should return null when no scope in tree', (tester) async {
      FairyScopeData? capturedData;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedData = FairyScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(capturedData, isNull);
    });

    group('viewModel parameter', () {
      testWidgets('should create and register ViewModel via factory',
          (tester) async {
        TestViewModel? vm;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => TestViewModel(),
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                vm = data?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );

        expect(vm, isNotNull);
        expect(vm, isA<TestViewModel>());
      });

      testWidgets('should create ViewModel only once per build',
          (tester) async {
        var createCount = 0;
        TestViewModel? vm;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              createCount++;
              return TestViewModel();
            },
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                vm = data?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );

        // Factory called once during initState
        expect(createCount, equals(1));
        expect(vm, isNotNull);

        // Rebuild (pump without changing widget tree) should NOT recreate VM
        await tester.pump();

        // Count stays at 1 - factory not called again
        expect(createCount, equals(1));

        // VM instance is the same
        final secondVm = FairyScope.of(tester.element(find.byType(Builder)))!
            .get<TestViewModel>();
        expect(identical(vm, secondVm), isTrue);
      });

      testWidgets('should mark created VM as owned by default', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => vm,
            child: const SizedBox(),
          ),
        );

        expect(vm.isDisposed, isFalse);

        // Remove scope
        await tester.pumpWidget(const SizedBox());

        // Should be disposed (owned by scope)
        expect(vm.isDisposed, isTrue);
      });
    });

    group('viewModels parameter', () {
      testWidgets('should create and register ViewModels via factories',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) => TestViewModel(),
              (locator) => AnotherViewModel(),
            ],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                expect(data!.contains<TestViewModel>(), isTrue);
                expect(data.contains<AnotherViewModel>(), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('should dispose created ViewModels by default',
          (tester) async {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
            ],
            child: const SizedBox(),
          ),
        );

        expect(vm1.isDisposed, isFalse);
        expect(vm2.isDisposed, isFalse);

        // Remove scope
        await tester.pumpWidget(const SizedBox());

        // Should be disposed (created by scope)
        expect(vm1.isDisposed, isTrue);
        expect(vm2.isDisposed, isTrue);
      });

      testWidgets('should register multiple ViewModels in order',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) => TestViewModel(),
              (locator) => AnotherViewModel(),
              (locator) => ThirdViewModel(),
            ],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context)!;
                expect(data.get<TestViewModel>(), isA<TestViewModel>());
                expect(data.get<AnotherViewModel>(), isA<AnotherViewModel>());
                expect(data.get<ThirdViewModel>(), isA<ThirdViewModel>());
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('autoDispose parameter', () {
      testWidgets('should dispose created VM when autoDispose is true',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => vm,
            autoDispose: true,
            child: const SizedBox(),
          ),
        );

        expect(vm.isDisposed, isFalse);

        await tester.pumpWidget(const SizedBox());

        expect(vm.isDisposed, isTrue);
      });

      testWidgets('should NOT dispose created VM when autoDispose is false',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => vm,
            autoDispose: false,
            child: const SizedBox(),
          ),
        );

        expect(vm.isDisposed, isFalse);

        await tester.pumpWidget(const SizedBox());

        expect(vm.isDisposed, isFalse);
      });

      testWidgets('should default autoDispose to true', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => vm,
            // autoDispose not specified (defaults to true)
            child: const SizedBox(),
          ),
        );

        await tester.pumpWidget(const SizedBox());

        expect(vm.isDisposed, isTrue);
      });
    });

    group('disposal behavior', () {
      testWidgets('should dispose all created ViewModels', (tester) async {
        final createdVm1 = TestViewModel();
        final createdVm2 = AnotherViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) => createdVm1,
              (locator) => createdVm2,
            ],
            child: const SizedBox(),
          ),
        );

        expect(createdVm1.isDisposed, isFalse);
        expect(createdVm2.isDisposed, isFalse);

        // Remove scope
        await tester.pumpWidget(const SizedBox());

        // Both should be disposed (created by scope)
        expect(createdVm1.isDisposed, isTrue);
        expect(createdVm2.isDisposed, isTrue);
      });

      testWidgets('should handle dispose on widget removal', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => vm,
            child: const SizedBox(),
          ),
        );

        expect(vm.isDisposed, isFalse);

        // Replace with different widget
        await tester.pumpWidget(
            const Text('New widget', textDirection: TextDirection.ltr));

        expect(vm.isDisposed, isTrue);
      });

      testWidgets('should not throw when disposing twice', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (_) => vm,
            child: const SizedBox(),
          ),
        );

        await tester.pumpWidget(const SizedBox());

        // Should not throw even if dispose is called again
        expect(() => vm.dispose(), returnsNormally);
      });
    });

    group('nested scopes', () {
      testWidgets('should support nested scopes', (tester) async {
        TestViewModel? outerVm;
        AnotherViewModel? innerVm;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => TestViewModel(),
            child: Builder(
              builder: (outerContext) {
                final outerData = FairyScope.of(outerContext);
                outerVm = outerData?.get<TestViewModel>();

                return FairyScope(
                  viewModel: (locator) => AnotherViewModel(),
                  child: Builder(
                    builder: (innerContext) {
                      final innerData = FairyScope.of(innerContext);
                      innerVm = innerData?.get<AnotherViewModel>();
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(outerVm, isNotNull);
        expect(innerVm, isNotNull);
      });

      testWidgets('should access nearest scope', (tester) async {
        AnotherViewModel? innerScopeVm;
        bool? hasTestVmInInnerScope;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => TestViewModel(),
            child: FairyScope(
              viewModel: (locator) => AnotherViewModel(),
              child: Builder(
                builder: (context) {
                  final data = FairyScope.of(context);
                  innerScopeVm = data?.get<AnotherViewModel>();
                  hasTestVmInInnerScope = data?.contains<TestViewModel>();
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Inner scope should have AnotherViewModel
        expect(innerScopeVm, isNotNull);
        // But not TestViewModel (that's in outer scope)
        expect(hasTestVmInInnerScope, isFalse);
      });

      testWidgets('should dispose nested scopes independently', (tester) async {
        final outerVm = TestViewModel();
        final innerVm = AnotherViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => outerVm,
            child: FairyScope(
              viewModel: (locator) => innerVm,
              child: const SizedBox(),
            ),
          ),
        );

        expect(outerVm.isDisposed, isFalse);
        expect(innerVm.isDisposed, isFalse);

        // Remove entire tree
        await tester.pumpWidget(const SizedBox());

        expect(outerVm.isDisposed, isTrue);
        expect(innerVm.isDisposed, isTrue);
      });
    });

    group('integration scenarios', () {
      testWidgets('should work with typical page scenario', (tester) async {
        final viewModel = PageViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => viewModel,
            child: const _TestPageWidget(),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);

        // Increment
        viewModel.increment();
        await tester.pump();

        expect(find.text('Count: 1'), findsOneWidget);
      });

      testWidgets(
          'should throw assertion if both viewModel and viewModels are provided',
          (tester) async {
        // Trying to use both parameters should trigger assertion
        expect(
          () => FairyScope(
            viewModel: (locator) => AnotherViewModel(),
            viewModels: [(locator) => TestViewModel()],
            child: const SizedBox(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      testWidgets('should create new ViewModels on widget replacement',
          (tester) async {
        var createCount = 0;

        // First scope with key 1
        await tester.pumpWidget(
          FairyScope(
            key: const ValueKey(1),
            viewModel: (locator) {
              createCount++;
              return PageViewModel();
            },
            child: Builder(
              builder: (context) {
                final vm = FairyScope.of(context)!.get<PageViewModel>();
                return Text('Count: ${vm.count}',
                    textDirection: TextDirection.ltr);
              },
            ),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);
        expect(createCount, equals(1));

        // Replace with new scope (different key forces new State)
        await tester.pumpWidget(
          FairyScope(
            key: const ValueKey(2),
            viewModel: (locator) {
              createCount++;
              return PageViewModel();
            },
            child: Builder(
              builder: (context) {
                final vm = FairyScope.of(context)!.get<PageViewModel>();
                return Text('Count: ${vm.count}',
                    textDirection: TextDirection.ltr);
              },
            ),
          ),
        );

        // New VM created because we used a different key
        expect(createCount, equals(2));
        expect(find.text('Count: 0'), findsOneWidget); // Fresh state
      });
    });
  });

  group('FairyScopeLocator', () {
    setUp(() {
      // Reset FairyLocator before each test
      FairyLocator.instance.reset();
    });

    group('dependency resolution from FairyLocator', () {
      testWidgets('should resolve service from FairyLocator', (tester) async {
        // Register service globally
        final service = TestService();
        FairyLocator.instance.registerSingleton<TestService>(service);

        TestViewModel? vm;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              final resolvedService = locator.get<TestService>();
              expect(identical(resolvedService, service), isTrue);
              return TestViewModel();
            },
            child: Builder(
              builder: (context) {
                vm = FairyScope.of(context)?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );

        expect(vm, isNotNull);
      });

      testWidgets('should inject multiple services from FairyLocator',
          (tester) async {
        final service1 = TestService();
        final service2 = AnotherService();

        FairyLocator.instance.registerSingleton<TestService>(service1);
        FairyLocator.instance.registerSingleton<AnotherService>(service2);

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => ViewModelWithDependencies(
              locator.get<TestService>(),
              locator.get<AnotherService>(),
            ),
            child: Builder(
              builder: (context) {
                final vm =
                    FairyScope.of(context)!.get<ViewModelWithDependencies>();
                expect(identical(vm.service1, service1), isTrue);
                expect(identical(vm.service2, service2), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('should throw error if service not registered',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              locator.get<TestService>(); // Not registered!
              return TestViewModel();
            },
            child: const SizedBox(),
          ),
        );

        // Exception thrown during build is captured by test framework
        final exception = tester.takeException();
        expect(exception, isA<StateError>());
        expect(exception.toString(),
            contains('No dependency of type TestService'));
      });
    });

    group('dependency resolution from parent FairyScope', () {
      testWidgets('should resolve ViewModel from parent scope', (tester) async {
        final parentVm = TestViewModel();
        ViewModelWithDependencies? childVm;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => parentVm,
            child: FairyScope(
              viewModel: (locator) {
                final resolved = locator.get<TestViewModel>();
                expect(identical(resolved, parentVm), isTrue);
                return ViewModelWithDependencies(
                    TestService(), AnotherService());
              },
              child: Builder(
                builder: (context) {
                  childVm =
                      FairyScope.of(context)?.get<ViewModelWithDependencies>();
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(childVm, isNotNull);
      });

      testWidgets('should resolve from nearest scope first', (tester) async {
        final rootVm = TestViewModel();
        final middleVm = AnotherViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => rootVm,
            child: FairyScope(
              viewModel: (locator) => middleVm,
              child: FairyScope(
                viewModel: (locator) {
                  // Should get middle scope's VM
                  final resolved = locator.get<AnotherViewModel>();
                  expect(identical(resolved, middleVm), isTrue);
                  return ThirdViewModel();
                },
                child: const SizedBox(),
              ),
            ),
          ),
        );
      });

      testWidgets('should traverse up scope hierarchy', (tester) async {
        final grandparentVm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => grandparentVm,
            child: FairyScope(
              viewModel: (locator) => AnotherViewModel(),
              child: FairyScope(
                viewModel: (locator) {
                  // Should traverse up to grandparent scope
                  final resolved = locator.get<TestViewModel>();
                  expect(identical(resolved, grandparentVm), isTrue);
                  return ThirdViewModel();
                },
                child: const SizedBox(),
              ),
            ),
          ),
        );
      });
    });

    group('dependency resolution from same scope (sequential)', () {
      testWidgets('should resolve ViewModels created earlier in same scope',
          (tester) async {
        TestViewModel? firstVm;
        ViewModelWithDependencies? secondVm;

        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) {
                firstVm = TestViewModel();
                return firstVm!;
              },
              (locator) {
                // Should be able to get first VM
                final resolved = locator.get<TestViewModel>();
                expect(identical(resolved, firstVm), isTrue);
                secondVm =
                    ViewModelWithDependencies(TestService(), AnotherService());
                return secondVm!;
              },
            ],
            child: const SizedBox(),
          ),
        );

        expect(firstVm, isNotNull);
        expect(secondVm, isNotNull);
      });

      testWidgets('should support dependency chain in same scope',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) => TestViewModel(),
              (locator) => ViewModelWithDependencies(
                    TestService(),
                    AnotherService(),
                  ),
              (locator) => ComplexViewModel(
                    locator.get<TestViewModel>(),
                    locator.get<ViewModelWithDependencies>(),
                  ),
            ],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context)!;
                final complex = data.get<ComplexViewModel>();

                expect(complex.vm1, isA<TestViewModel>());
                expect(complex.vm2, isA<ViewModelWithDependencies>());
                expect(
                    identical(complex.vm1, data.get<TestViewModel>()), isTrue);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('should throw if trying to get ViewModel created later',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModels: [
              (locator) {
                // Try to get VM that will be created later
                locator.get<AnotherViewModel>(); // Not created yet!
                return TestViewModel();
              },
              (locator) => AnotherViewModel(),
            ],
            child: const SizedBox(),
          ),
        );

        // Exception thrown during build is captured by test framework
        final exception = tester.takeException();
        expect(exception, isA<StateError>());
        expect(exception.toString(),
            contains('No dependency of type AnotherViewModel'));
      });
    });

    group('hybrid resolution (scope + locator)', () {
      testWidgets('should resolve from both parent scope and FairyLocator',
          (tester) async {
        final service = TestService();
        FairyLocator.instance.registerSingleton<TestService>(service);

        final parentVm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => parentVm,
            child: FairyScope(
              viewModel: (locator) => ViewModelWithMixedDependencies(
                locator.get<TestService>(), // From FairyLocator
                locator.get<TestViewModel>(), // From parent scope
              ),
              child: Builder(
                builder: (context) {
                  final vm = FairyScope.of(context)!
                      .get<ViewModelWithMixedDependencies>();
                  expect(identical(vm.service, service), isTrue);
                  expect(identical(vm.viewModel, parentVm), isTrue);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      });

      testWidgets('should prefer parent scope over FairyLocator for same type',
          (tester) async {
        // Register in FairyLocator
        final globalVm = TestViewModel();
        FairyLocator.instance.registerSingleton<TestViewModel>(globalVm);

        // Register in parent scope (should shadow global)
        final scopedVm = TestViewModel();

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => scopedVm,
            child: FairyScope(
              viewModel: (locator) {
                final resolved = locator.get<TestViewModel>();
                // Should get scoped VM, not global
                expect(identical(resolved, scopedVm), isTrue);
                expect(identical(resolved, globalVm), isFalse);
                return AnotherViewModel();
              },
              child: const SizedBox(),
            ),
          ),
        );
      });
    });

    group('locator lifecycle and safety', () {
      testWidgets('should invalidate locator after initialization',
          (tester) async {
        FairyScopeLocator? capturedLocator;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              capturedLocator = locator;
              return TestViewModel();
            },
            child: const SizedBox(),
          ),
        );

        // Trying to use locator after initialization should throw
        // AssertionError in debug mode, StateError in release mode
        expect(
          () => capturedLocator!.get<TestService>(),
          throwsA(anyOf(isA<AssertionError>(), isA<StateError>())),
        );
      });

      testWidgets('should show helpful error when used outside init',
          (tester) async {
        FairyScopeLocator? capturedLocator;

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              capturedLocator = locator;
              return TestViewModel();
            },
            child: const SizedBox(),
          ),
        );

        try {
          capturedLocator!.get<TestService>();
          fail('Should have thrown');
        } catch (e) {
          // In debug mode: AssertionError with message about invalidation
          // In release mode: StateError with helpful message
          expect(
            e.toString(),
            anyOf(
              contains('FairyScopeLocator used after invalidation'),
              contains('only be used during ViewModel initialization'),
            ),
          );
          // Only check for detailed message if it's StateError (release mode)
          if (e is StateError) {
            expect(e.toString(), contains('Do not store references'));
          }
        }
      });

      testWidgets('should not allow storing locator in ViewModel',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => BadViewModelWithStoredLocator(locator),
            child: const SizedBox(),
          ),
        );

        // Get the VM and try to use stored locator
        final BuildContext context = tester.element(find.byType(SizedBox));
        final vm = FairyScope.of(context)!.get<BadViewModelWithStoredLocator>();

        // Should throw when trying to use stored locator
        // AssertionError in debug mode, StateError in release mode
        expect(
          () => vm.tryToUseLocator(),
          throwsA(anyOf(isA<AssertionError>(), isA<StateError>())),
        );
      });
    });

    group('error handling', () {
      testWidgets('should provide clear error for missing dependency',
          (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              locator.get<NonExistentService>();
              return TestViewModel();
            },
            child: const SizedBox(),
          ),
        );

        final exception = tester.takeException();
        expect(exception, isNotNull);
        expect(exception.toString(), contains('No dependency'));
        expect(exception.toString(), contains('NonExistentService'));
        expect(exception.toString(),
            contains('FairyScope hierarchy or FairyLocator'));
      });

      testWidgets('should provide helpful resolution guidance', (tester) async {
        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) {
              locator.get<TestService>();
              return TestViewModel();
            },
            child: const SizedBox(),
          ),
        );

        final exception = tester.takeException();
        expect(exception, isNotNull);
        expect(exception.toString(), contains('Make sure to'));
        expect(exception.toString(), contains('registerSingleton'));
        expect(exception.toString(), contains('parent FairyScope'));
      });
    });

    group('complex scenarios', () {
      testWidgets('should handle deep nesting with mixed dependencies',
          (tester) async {
        final service = TestService();
        FairyLocator.instance.registerSingleton<TestService>(service);

        await tester.pumpWidget(
          FairyScope(
            viewModel: (locator) => TestViewModel(),
            child: FairyScope(
              viewModels: [
                (locator) => AnotherViewModel(),
                (locator) => ViewModelWithDependencies(
                      TestService(),
                      AnotherService(),
                    ),
              ],
              child: FairyScope(
                viewModel: (locator) => ComplexViewModel(
                  locator.get<TestViewModel>(), // From grandparent
                  locator.get<ViewModelWithDependencies>(), // From parent
                ),
                child: Builder(
                  builder: (context) {
                    final data = FairyScope.of(context)!;
                    final complex = data.get<ComplexViewModel>();

                    expect(complex.vm1, isA<TestViewModel>());
                    expect(complex.vm2, isA<ViewModelWithDependencies>());

                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
      });

      testWidgets(
          'should resolve correctly with same-type VMs in different scopes',
          (tester) async {
        final scope1Vm = TestViewModel();
        final scope2Vm = TestViewModel();

        await tester.pumpWidget(
          Row(
            textDirection: TextDirection.ltr,
            children: [
              FairyScope(
                viewModel: (locator) => scope1Vm,
                child: Builder(
                  builder: (context) {
                    final vm = FairyScope.of(context)!.get<TestViewModel>();
                    expect(identical(vm, scope1Vm), isTrue);
                    return const SizedBox();
                  },
                ),
              ),
              FairyScope(
                viewModel: (locator) => scope2Vm,
                child: Builder(
                  builder: (context) {
                    final vm = FairyScope.of(context)!.get<TestViewModel>();
                    expect(identical(vm, scope2Vm), isTrue);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        );
      });
    });
  });
}

// Test helper classes

class TestViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class AnotherViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class ThirdViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class PageViewModel extends ObservableObject {
  int count = 0;

  void increment() {
    count++;
    onPropertyChanged();
  }
}

// Test service classes
class TestService {
  String getData() => 'test data';
}

class AnotherService {
  int getValue() => 42;
}

class NonExistentService {
  void doSomething() {}
}

// ViewModels with dependencies
class ViewModelWithDependencies extends ObservableObject {
  final TestService service1;
  final AnotherService service2;

  ViewModelWithDependencies(this.service1, this.service2);

  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

class ViewModelWithMixedDependencies extends ObservableObject {
  final TestService service;
  final TestViewModel viewModel;

  ViewModelWithMixedDependencies(this.service, this.viewModel);

  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

class ComplexViewModel extends ObservableObject {
  final TestViewModel vm1;
  final ViewModelWithDependencies vm2;

  ComplexViewModel(this.vm1, this.vm2);

  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

class BadViewModelWithStoredLocator extends ObservableObject {
  final FairyScopeLocator _locator;

  BadViewModelWithStoredLocator(this._locator);

  void tryToUseLocator() {
    // This should throw because locator is invalidated
    _locator.get<TestService>();
  }

  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

// Helper widget that rebuilds when PageViewModel changes
class _TestPageWidget extends StatefulWidget {
  const _TestPageWidget();

  @override
  State<_TestPageWidget> createState() => _TestPageWidgetState();
}

class _TestPageWidgetState extends State<_TestPageWidget> {
  late PageViewModel _vm;

  VoidCallback? _vmDisposer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = FairyScope.of(context)!;
    _vm = data.get<PageViewModel>();
    _vmDisposer = _vm.propertyChanged(_onVmChanged);
  }

  void _onVmChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _vmDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Count: ${_vm.count}',
      textDirection: TextDirection.ltr,
    );
  }
}
